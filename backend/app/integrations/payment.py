import hashlib
import hmac
import logging
from typing import Optional

import httpx

from app.config import get_settings

logger = logging.getLogger("dairy_ai.integrations.payment")

RAZORPAY_BASE_URL = "https://api.razorpay.com/v1"


class RazorpayClient:
    """Integration with Razorpay payment gateway for orders, payments, refunds,
    payment links, and transfers (vet payouts)."""

    @staticmethod
    def _auth() -> tuple[str, str]:
        """Return Basic Auth credentials (key_id, key_secret)."""
        settings = get_settings()
        return (settings.RAZORPAY_KEY_ID, settings.RAZORPAY_KEY_SECRET)

    @staticmethod
    async def create_order(
        amount_paise: int,
        currency: str = "INR",
        receipt: Optional[str] = None,
        notes: Optional[dict] = None,
    ) -> Optional[dict]:
        """Create a Razorpay order.

        Args:
            amount_paise: Amount in paise (e.g. 50000 = Rs 500).
            currency: Currency code, default INR.
            receipt: Unique receipt identifier for your records.
            notes: Key-value pairs for metadata (max 15 keys).

        Returns:
            Razorpay order dict with 'id', 'amount', 'status', etc., or None on failure.
        """
        logger.info(
            "Creating order: amount=%d paise, currency=%s, receipt=%s",
            amount_paise, currency, receipt,
        )

        payload: dict = {
            "amount": amount_paise,
            "currency": currency,
        }
        if receipt:
            payload["receipt"] = receipt
        if notes:
            payload["notes"] = notes

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{RAZORPAY_BASE_URL}/orders",
                    auth=RazorpayClient._auth(),
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Razorpay create_order error: status=%d, body=%s",
                        response.status_code, result,
                    )
                    return None
                logger.info(
                    "Order created: order_id=%s, amount=%d, status=%s",
                    result.get("id"), amount_paise, result.get("status"),
                )
                return result
        except Exception as e:
            logger.exception("Exception creating Razorpay order: %s", e)
            return None

    @staticmethod
    async def verify_payment(
        razorpay_order_id: str,
        razorpay_payment_id: str,
        razorpay_signature: str,
    ) -> bool:
        """Verify Razorpay payment signature to confirm authenticity.

        Uses HMAC-SHA256 with key_secret to validate that the payment
        callback is genuine and has not been tampered with.

        Args:
            razorpay_order_id: The order ID from the order creation step.
            razorpay_payment_id: The payment ID received in the callback.
            razorpay_signature: The signature received in the callback.

        Returns:
            True if signature is valid, False otherwise.
        """
        logger.info(
            "Verifying payment: order_id=%s, payment_id=%s",
            razorpay_order_id, razorpay_payment_id,
        )
        settings = get_settings()
        message = f"{razorpay_order_id}|{razorpay_payment_id}"
        expected_signature = hmac.new(
            settings.RAZORPAY_KEY_SECRET.encode("utf-8"),
            message.encode("utf-8"),
            hashlib.sha256,
        ).hexdigest()

        is_valid = hmac.compare_digest(expected_signature, razorpay_signature)
        if is_valid:
            logger.info(
                "Payment verified successfully: order_id=%s, payment_id=%s",
                razorpay_order_id, razorpay_payment_id,
            )
        else:
            logger.warning(
                "Payment signature mismatch: order_id=%s, payment_id=%s",
                razorpay_order_id, razorpay_payment_id,
            )
        return is_valid

    @staticmethod
    async def fetch_payment(payment_id: str) -> Optional[dict]:
        """Fetch details of a specific payment.

        Args:
            payment_id: Razorpay payment ID (e.g. 'pay_XXXXXXXX').

        Returns:
            Payment details dict, or None on failure.
        """
        logger.info("Fetching payment: payment_id=%s", payment_id)

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.get(
                    f"{RAZORPAY_BASE_URL}/payments/{payment_id}",
                    auth=RazorpayClient._auth(),
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Razorpay fetch_payment error: status=%d, payment_id=%s, body=%s",
                        response.status_code, payment_id, result,
                    )
                    return None
                logger.info(
                    "Payment fetched: payment_id=%s, status=%s, amount=%s",
                    payment_id, result.get("status"), result.get("amount"),
                )
                return result
        except Exception as e:
            logger.exception("Exception fetching Razorpay payment %s: %s", payment_id, e)
            return None

    @staticmethod
    async def create_refund(
        payment_id: str,
        amount_paise: Optional[int] = None,
        reason: Optional[str] = None,
    ) -> Optional[dict]:
        """Create a refund for a captured payment.

        Args:
            payment_id: Razorpay payment ID to refund.
            amount_paise: Partial refund amount in paise. If None, full refund.
            reason: Reason for refund (shown to customer).

        Returns:
            Refund details dict, or None on failure.
        """
        logger.info(
            "Creating refund: payment_id=%s, amount=%s paise, reason=%s",
            payment_id, amount_paise, reason,
        )

        payload: dict = {}
        if amount_paise is not None:
            payload["amount"] = amount_paise
        if reason:
            payload["notes"] = {"reason": reason}

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{RAZORPAY_BASE_URL}/payments/{payment_id}/refunds",
                    auth=RazorpayClient._auth(),
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Razorpay create_refund error: status=%d, payment_id=%s, body=%s",
                        response.status_code, payment_id, result,
                    )
                    return None
                logger.info(
                    "Refund created: refund_id=%s, payment_id=%s, amount=%s, status=%s",
                    result.get("id"), payment_id, result.get("amount"), result.get("status"),
                )
                return result
        except Exception as e:
            logger.exception("Exception creating refund for %s: %s", payment_id, e)
            return None

    @staticmethod
    async def create_payment_link(
        amount_paise: int,
        description: str,
        customer_name: str,
        customer_phone: str,
        expire_minutes: int = 30,
    ) -> Optional[str]:
        """Create a Razorpay payment link (useful for WhatsApp-based payments).

        Args:
            amount_paise: Amount in paise.
            description: Payment description shown to customer.
            customer_name: Customer full name.
            customer_phone: Customer phone number (with country code).
            expire_minutes: Link expiry time in minutes from now.

        Returns:
            Short payment link URL string, or None on failure.
        """
        logger.info(
            "Creating payment link: amount=%d paise, customer=%s, phone=%s, expire=%d min",
            amount_paise, customer_name, customer_phone, expire_minutes,
        )

        import time

        expire_by = int(time.time()) + (expire_minutes * 60)

        payload = {
            "amount": amount_paise,
            "currency": "INR",
            "description": description,
            "customer": {
                "name": customer_name,
                "contact": customer_phone,
            },
            "notify": {
                "sms": True,
                "whatsapp": True,
            },
            "reminder_enable": True,
            "expire_by": expire_by,
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{RAZORPAY_BASE_URL}/payment_links",
                    auth=RazorpayClient._auth(),
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Razorpay create_payment_link error: status=%d, body=%s",
                        response.status_code, result,
                    )
                    return None

                short_url = result.get("short_url", "")
                logger.info(
                    "Payment link created: link_id=%s, short_url=%s, amount=%d paise",
                    result.get("id"), short_url, amount_paise,
                )
                return short_url if short_url else None
        except Exception as e:
            logger.exception("Exception creating Razorpay payment link: %s", e)
            return None

    @staticmethod
    async def create_transfer(
        payment_id: str,
        amount_paise: int,
        recipient_account_id: str,
    ) -> Optional[dict]:
        """Create a transfer (Route) from a captured payment to a linked account.

        Used for auto-payout to vets after consultation completion.

        Args:
            payment_id: Source payment ID (already captured).
            amount_paise: Amount to transfer in paise.
            recipient_account_id: Razorpay linked account ID (e.g. 'acc_XXXXXXXX').

        Returns:
            Transfer details dict, or None on failure.
        """
        logger.info(
            "Creating transfer: payment_id=%s, amount=%d paise, recipient=%s",
            payment_id, amount_paise, recipient_account_id,
        )

        payload = {
            "transfers": [
                {
                    "account": recipient_account_id,
                    "amount": amount_paise,
                    "currency": "INR",
                    "on_hold": False,
                }
            ],
        }

        try:
            async with httpx.AsyncClient(timeout=30.0) as client:
                response = await client.post(
                    f"{RAZORPAY_BASE_URL}/payments/{payment_id}/transfers",
                    auth=RazorpayClient._auth(),
                    json=payload,
                )
                result = response.json()
                if response.status_code >= 400:
                    logger.error(
                        "Razorpay create_transfer error: status=%d, payment_id=%s, body=%s",
                        response.status_code, payment_id, result,
                    )
                    return None

                transfers = result.get("items", [])
                if transfers:
                    transfer = transfers[0]
                    logger.info(
                        "Transfer created: transfer_id=%s, payment_id=%s, recipient=%s, amount=%d",
                        transfer.get("id"), payment_id, recipient_account_id, amount_paise,
                    )
                    return transfer

                logger.warning(
                    "Transfer response has no items: payment_id=%s, body=%s",
                    payment_id, result,
                )
                return result
        except Exception as e:
            logger.exception(
                "Exception creating transfer from %s to %s: %s",
                payment_id, recipient_account_id, e,
            )
            return None
