"""Delhivery B2C adapter. Credentials are server-side and opt-in."""
import json
from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal, InvalidOperation
from zoneinfo import ZoneInfo

import httpx

from app.config import settings


class CourierUnavailable(Exception):
    """A courier did not accept a quote or shipment."""


class BookingUncertain(Exception):
    """A booking may have succeeded; reconcile before another attempt."""


@dataclass(frozen=True)
class CourierQuote:
    code: str
    name: str
    cost: Decimal
    estimated_days: int | None = None


class DelhiveryShipping:
    code = "delhivery"
    name = "Delhivery"

    def __init__(self, transport: httpx.AsyncBaseTransport | None = None):
        self.transport = transport
        self.base_url = (
            "https://track.delhivery.com"
            if settings.DELHIVERY_ENV == "production"
            else "https://staging-express.delhivery.com"
        )

    @property
    def configured(self) -> bool:
        return bool(settings.DELHIVERY_TOKEN and settings.DELHIVERY_CLIENT_NAME and settings.DELHIVERY_PICKUP_LOCATION)

    def _client(self) -> httpx.AsyncClient:
        return httpx.AsyncClient(
            base_url=self.base_url,
            headers={"Authorization": f"Token {settings.DELHIVERY_TOKEN}"},
            timeout=8.0,
            transport=self.transport,
        )

    async def quote(self, destination_pin: str, grams: int, cod: bool) -> CourierQuote | None:
        if not self.configured or grams <= 0:
            return None
        try:
            async with self._client() as client:
                pins = await client.get("/c/api/pin-codes/json/", params={"filter_codes": destination_pin})
                pins.raise_for_status()
                codes = pins.json().get("delivery_codes") or []
                if not codes:
                    return None
                postal = codes[0].get("postal_code") or {}
                if str(postal.get("pin")) != destination_pin or postal.get("remarks"):
                    return None
                if str(postal.get("cod" if cod else "pre_paid", "N")).upper() != "Y":
                    return None
                price = await client.get(
                    "/api/kinko/v1/invoice/charges/.json",
                    params={
                        "md": "S", "ss": "Delivered", "d_pin": destination_pin,
                        "o_pin": settings.SHIPPING_ORIGIN_PINCODE, "cgm": grams,
                        "pt": "COD" if cod else "Pre-paid",
                    },
                )
                price.raise_for_status()
                raw = price.json()
                amount = raw.get("total_amount") if isinstance(raw, dict) else None
                if amount is None:
                    return None
                cost = Decimal(str(amount))
                # Staging returns zero because contract rates are absent there.
                if not cost.is_finite() or cost <= 0:
                    return None
                return CourierQuote(self.code, self.name, cost.quantize(Decimal("0.01")))
        except (httpx.HTTPError, ValueError, InvalidOperation, TypeError, KeyError):
            return None

    async def find_existing(self, order_reference: str) -> str | None:
        if not self.configured:
            raise CourierUnavailable("Delhivery is not configured")
        try:
            async with self._client() as client:
                response = await client.get("/api/v1/packages/json/", params={"ref_ids": order_reference})
                response.raise_for_status()
                body = response.json()
                if not isinstance(body, dict) or "ShipmentData" not in body:
                    raise BookingUncertain("Courier lookup did not confirm the order state")
                for entry in body.get("ShipmentData") or []:
                    shipment = entry.get("Shipment") or {}
                    if str(shipment.get("ReferenceNo")) == order_reference and shipment.get("AWB"):
                        return str(shipment["AWB"])
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            raise BookingUncertain("Courier lookup failed; do not create another booking") from exc
        return None

    async def book(self, order, address: dict, item_names: list[str], package: dict, payment_method: str) -> str:
        if not self.configured:
            raise CourierUnavailable("Delhivery credentials and pickup location are not configured")
        if settings.DELHIVERY_ENV == "production" and settings.APP_ENV.lower() != "production":
            raise CourierUnavailable("Live courier booking requires a production application")
        existing = await self.find_existing(str(order.id))
        if existing:
            return existing
        name = str(address.get("recipient_name") or "").strip()
        phone = str(address.get("phone") or "").strip()
        pin = str(address.get("postal_code") or "").strip()
        street = ", ".join(str(address.get(k) or "").strip() for k in ("address_line1", "address_line2", "landmark") if address.get(k))
        if not name or not phone or len(pin) != 6 or not street:
            raise CourierUnavailable("The delivery address is incomplete")
        is_cod = payment_method == "cod"
        shipment = {
            "order": str(order.id), "name": name, "phone": phone,
            "add": street, "city": address.get("village_or_city") or address.get("district") or "",
            "state": address.get("state") or "", "pin": pin, "country": "India",
            "payment_mode": "COD" if is_cod else "Pre-paid",
            "cod_amount": str(order.total) if is_cod else "0",
            "total_amount": str(order.total),
            "products_desc": ", ".join(item_names)[:200],
            "quantity": str(package.get("quantity", 1)),
            "weight": str(package["weight_grams"]),
            "shipment_length": str(package["length_cm"]),
            "shipment_width": str(package["width_cm"]),
            "shipment_height": str(package["height_cm"]),
        }
        payload = {
            "client": settings.DELHIVERY_CLIENT_NAME,
            "pickup_location": {"name": settings.DELHIVERY_PICKUP_LOCATION},
            "shipments": [shipment],
        }
        try:
            async with self._client() as client:
                response = await client.post(
                    "/api/cmu/create.json", data={"format": "json", "data": json.dumps(payload)}
                )
                response.raise_for_status()
                body = response.json()
                packages = body.get("packages") or []
                if packages:
                    first = packages[0]
                    awb = first.get("waybill") or first.get("wb")
                    if awb and str(first.get("status", "Success")).lower() not in {"failed", "error"}:
                        return str(awb)
                # Delhivery documents errors that may leave an order partially saved.
                raise BookingUncertain("Courier response did not confirm an AWB; check the courier account")
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            raise BookingUncertain("Courier booking outcome is unknown; reconciliation is required") from exc

    async def label_pdf(self, awb: str) -> bytes:
        async with self._client() as client:
            response = await client.get("/api/p/packing_slip", params={"wbns": awb, "pdf": "True"})
            response.raise_for_status()
            if not response.content.startswith(b"%PDF"):
                raise CourierUnavailable("The courier did not return a PDF label")
            return response.content

    async def request_pickup(self, count: int) -> None:
        local = datetime.now(ZoneInfo("Asia/Kolkata"))
        pickup_time = settings.DELHIVERY_PICKUP_TIME
        scheduled = local.date()
        if local.strftime("%H:%M:%S") >= pickup_time or scheduled.weekday() == 6:
            scheduled += timedelta(days=1)
        if scheduled.weekday() == 6:
            scheduled += timedelta(days=1)
        async with self._client() as client:
            response = await client.post("/fm/request/new/", data={
                "pickup_date": scheduled.isoformat(), "pickup_time": pickup_time,
                "pickup_location": settings.DELHIVERY_PICKUP_LOCATION,
                "expected_package_count": count,
            })
            if response.status_code >= 400 and "already exist" not in response.text.lower():
                response.raise_for_status()

    async def track(self, awb: str) -> list[dict]:
        async with self._client() as client:
            response = await client.get("/api/v1/packages/json/", params={"waybill": awb})
            response.raise_for_status()
            data = response.json().get("ShipmentData") or []
        if not data:
            return []
        shipment = data[0].get("Shipment") or {}
        scans = shipment.get("Scans") or []
        events = []
        for entry in scans:
            scan = entry.get("ScanDetail") or {}
            occurred = scan.get("ScanDateTime")
            description = str(scan.get("Instructions") or scan.get("Scan") or "")
            if not occurred or not description:
                continue
            events.append({
                "key": f"{awb}:{occurred}:{description}",
                "status": str(scan.get("Scan") or ""),
                "description": description[:500],
                "location": str(scan.get("ScannedLocation") or "")[:200],
                "occurred_at": occurred,
            })
        return events
