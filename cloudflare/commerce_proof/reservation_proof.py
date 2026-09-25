"""SQLite harness for the D1 reservation SQL; not a production order API."""

from __future__ import annotations

import hashlib
import json
import sqlite3
import uuid
from pathlib import Path
from typing import Iterable


SCHEMA = Path(__file__).with_name("0001_reservation.sql")


class ReservationError(Exception):
    pass


class InsufficientStock(ReservationError):
    pass


class PriceChanged(ReservationError):
    pass


class IdempotencyConflict(ReservationError):
    pass


def connect(path: Path) -> sqlite3.Connection:
    connection = sqlite3.connect(path, timeout=10, isolation_level=None)
    connection.execute("PRAGMA foreign_keys = ON")
    connection.execute("PRAGMA busy_timeout = 10000")
    return connection


def create_schema(connection: sqlite3.Connection) -> None:
    connection.executescript(SCHEMA.read_text(encoding="utf-8"))


def _normalize_lines(
    lines: Iterable[tuple[str, int, int]],
) -> list[tuple[str, int, int]]:
    normalized = sorted(lines)
    if not normalized:
        raise ValueError("a reservation needs at least one line")
    if len({line[0] for line in normalized}) != len(normalized):
        raise ValueError("duplicate products must be combined before reservation")
    for product_id, quantity, price_minor in normalized:
        if not product_id or type(quantity) is not int or quantity <= 0:
            raise ValueError("invalid product or quantity")
        if type(price_minor) is not int or price_minor < 0:
            raise ValueError("price must be nonnegative integer minor units")
    return normalized


def payload_hash(customer_id: str, lines: Iterable[tuple[str, int, int]]) -> str:
    canonical = json.dumps(
        {"customer_id": customer_id, "currency": "INR", "lines": _normalize_lines(lines)},
        sort_keys=True,
        separators=(",", ":"),
    )
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


def _existing(
    connection: sqlite3.Connection,
    customer_id: str,
    idempotency_key: str,
    request_hash: str,
) -> str | None:
    row = connection.execute(
        """SELECT id, payload_sha256, status FROM proof_reservations
           WHERE customer_id = ? AND idempotency_key = ?""",
        (customer_id, idempotency_key),
    ).fetchone()
    if row is None:
        return None
    if row[1] != request_hash:
        raise IdempotencyConflict("key already belongs to a different payload")
    if row[2] != "RESERVED":
        raise ReservationError("existing reservation is incomplete")
    return row[0]


def reserve(
    connection: sqlite3.Connection,
    *,
    customer_id: str,
    idempotency_key: str,
    lines: Iterable[tuple[str, int, int]],
) -> str:
    """Mirror one D1 batch: parent, sorted lines, seal; replay by key and hash."""
    if not customer_id or not idempotency_key or len(idempotency_key) > 128:
        raise ValueError("customer and bounded idempotency key are required")
    normalized = _normalize_lines(lines)
    request_hash = payload_hash(customer_id, normalized)
    replay = _existing(connection, customer_id, idempotency_key, request_hash)
    if replay:
        return replay

    reservation_id = str(uuid.uuid4())
    try:
        connection.execute("BEGIN IMMEDIATE")
        connection.execute(
            """INSERT INTO proof_reservations
               (id, customer_id, idempotency_key, payload_sha256, expected_lines)
               VALUES (?, ?, ?, ?, ?)""",
            (reservation_id, customer_id, idempotency_key, request_hash, len(normalized)),
        )
        for product_id, quantity, price_minor in normalized:
            connection.execute(
                """INSERT INTO proof_reservation_lines
                   (reservation_id, product_id, quantity, unit_price_minor, currency)
                   VALUES (?, ?, ?, ?, 'INR')""",
                (reservation_id, product_id, quantity, price_minor),
            )
        connection.execute(
            "INSERT INTO proof_reservation_seals (reservation_id) VALUES (?)",
            (reservation_id,),
        )
        connection.execute("COMMIT")
    except sqlite3.Error as error:
        if connection.in_transaction:
            connection.execute("ROLLBACK")
        # A concurrent winner may have inserted this key after our preflight read.
        replay = _existing(connection, customer_id, idempotency_key, request_hash)
        if replay:
            return replay
        if "insufficient stock" in str(error):
            raise InsufficientStock(str(error)) from error
        if "price changed" in str(error):
            raise PriceChanged(str(error)) from error
        raise ReservationError(str(error)) from error
    return reservation_id
