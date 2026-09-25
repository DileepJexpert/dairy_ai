import concurrent.futures
import sqlite3
import threading
import unittest
import uuid
from pathlib import Path

from reservation_proof import (
    IdempotencyConflict,
    InsufficientStock,
    PriceChanged,
    connect,
    create_schema,
    payload_hash,
    reserve,
)


class ReservationProofTests(unittest.TestCase):
    def setUp(self):
        self.path = Path(__file__).parent / f"test-{uuid.uuid4()}.sqlite3"
        self.addCleanup(self.path.unlink, missing_ok=True)
        self.db = connect(self.path)
        self.addCleanup(self.db.close)
        create_schema(self.db)

    def stock(self, product_id):
        return self.db.execute(
            "SELECT available_units FROM proof_inventory WHERE product_id = ?",
            (product_id,),
        ).fetchone()[0]

    def add_stock(self, product_id, quantity, price_minor=500):
        self.db.execute(
            """INSERT INTO proof_inventory
               (product_id, available_units, price_minor, currency)
               VALUES (?, ?, ?, 'INR')""",
            (product_id, quantity, price_minor),
        )

    def reservation_count(self):
        return self.db.execute("SELECT COUNT(*) FROM proof_reservations").fetchone()[0]

    def test_hash_canonicalization_matches_worker(self):
        self.assertEqual(
            payload_hash("buyer", [("ghee", 1, 500)]),
            "984b219c1a7aab69d3a98af54bcf3056f33d075154d90bb1ee696e38558b4e18",
        )

    def test_two_customers_contend_for_last_unit(self):
        self.add_stock("ghee", 1)
        barrier = threading.Barrier(2)

        def attempt(customer):
            db = connect(self.path)
            try:
                barrier.wait(timeout=5)
                return reserve(
                    db,
                    customer_id=customer,
                    idempotency_key="checkout-1",
                    lines=[("ghee", 1, 500)],
                )
            finally:
                db.close()

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            futures = [pool.submit(attempt, customer) for customer in ("a", "b")]
            outcomes = []
            for future in futures:
                try:
                    outcomes.append(future.result(timeout=15))
                except InsufficientStock:
                    outcomes.append("insufficient")
        self.assertEqual(sum(value != "insufficient" for value in outcomes), 1)
        self.assertEqual(self.stock("ghee"), 0)
        self.assertEqual(self.reservation_count(), 1)

    def test_second_failed_item_rolls_back_first_decrement_and_parent(self):
        self.add_stock("a", 2)
        self.add_stock("b", 0)
        with self.assertRaises(InsufficientStock):
            reserve(
                self.db,
                customer_id="buyer",
                idempotency_key="basket-1",
                lines=[("a", 1, 500), ("b", 1, 500)],
            )
        self.assertEqual(self.stock("a"), 2)
        self.assertEqual(self.stock("b"), 0)
        self.assertEqual(self.reservation_count(), 0)
        self.assertEqual(
            self.db.execute("SELECT COUNT(*) FROM proof_reservation_lines").fetchone()[0],
            0,
        )

    def test_same_key_same_payload_replays_without_second_decrement(self):
        self.add_stock("ghee", 1)
        first = reserve(
            self.db,
            customer_id="buyer",
            idempotency_key="checkout-1",
            lines=[("ghee", 1, 500)],
        )
        second = reserve(
            self.db,
            customer_id="buyer",
            idempotency_key="checkout-1",
            lines=[("ghee", 1, 500)],
        )
        self.assertEqual(first, second)
        self.assertEqual(self.stock("ghee"), 0)
        self.assertEqual(self.reservation_count(), 1)

    def test_same_key_changed_payload_rejected_without_stock_change(self):
        self.add_stock("ghee", 3)
        reserve(
            self.db,
            customer_id="buyer",
            idempotency_key="checkout-1",
            lines=[("ghee", 1, 500)],
        )
        with self.assertRaises(IdempotencyConflict):
            reserve(
                self.db,
                customer_id="buyer",
                idempotency_key="checkout-1",
                lines=[("ghee", 2, 500)],
            )
        self.assertEqual(self.stock("ghee"), 2)
        self.assertEqual(self.reservation_count(), 1)

    def test_price_change_rejects_stale_checkout_and_rolls_back(self):
        self.add_stock("ghee", 1, price_minor=600)
        with self.assertRaises(PriceChanged):
            reserve(
                self.db,
                customer_id="buyer",
                idempotency_key="checkout-1",
                lines=[("ghee", 1, 500)],
            )
        self.assertEqual(self.stock("ghee"), 1)
        self.assertEqual(self.reservation_count(), 0)

    def test_constraints_and_seal_block_incomplete_reservation(self):
        self.add_stock("ghee", 1)
        self.db.execute(
            """INSERT INTO proof_reservations
               (id, customer_id, idempotency_key, payload_sha256, expected_lines)
               VALUES ('r', 'buyer', 'key', ?, 1)""",
            ("a" * 64,),
        )
        with self.assertRaisesRegex(sqlite3.IntegrityError, "incomplete reservation"):
            self.db.execute(
                "INSERT INTO proof_reservation_seals (reservation_id) VALUES ('r')"
            )
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute(
                """INSERT INTO proof_reservation_lines
                   (reservation_id, product_id, quantity, unit_price_minor, currency)
                   VALUES ('r', 'ghee', 0, 500, 'INR')"""
            )
        self.assertEqual(self.stock("ghee"), 1)


if __name__ == "__main__":
    unittest.main()
