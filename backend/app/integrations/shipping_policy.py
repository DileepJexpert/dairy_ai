"""Courier registry and deterministic coverage, price, and ETA selection."""
from typing import Protocol
from decimal import Decimal

from app.config import settings
from app.integrations.delhivery_shipping import CourierQuote, DelhiveryShipping


class CourierProvider(Protocol):
    code: str
    name: str
    configured: bool

    async def quote(self, destination_pin: str, grams: int, cod: bool) -> CourierQuote | None: ...
    async def book(self, order, address: dict, item_names: list[str], package: dict, payment_method: str) -> str: ...
    async def request_pickup(self, count: int) -> None: ...


def configured_providers() -> list[CourierProvider]:
    """Register another contracted adapter here after validating its API."""
    candidates: list[CourierProvider] = [DelhiveryShipping()]
    return [provider for provider in candidates if provider.configured]


def select_quote(options: list[tuple[CourierProvider, CourierQuote]]) -> tuple[CourierProvider, CourierQuote] | None:
    eligible = [pair for pair in options if pair[1].cost > 0]
    if settings.SHIPPING_MAX_COURIER_COST > 0:
        eligible = [pair for pair in eligible if pair[1].cost <= Decimal(str(settings.SHIPPING_MAX_COURIER_COST))]
    if settings.SHIPPING_MAX_DELIVERY_DAYS > 0:
        eligible = [pair for pair in eligible if pair[1].estimated_days is not None
                    and pair[1].estimated_days <= settings.SHIPPING_MAX_DELIVERY_DAYS]
    if not eligible:
        return None
    if settings.SHIPPING_SELECTION_STRATEGY == "fastest":
        return min(eligible, key=lambda pair: (pair[1].estimated_days if pair[1].estimated_days is not None else 999, pair[1].cost, pair[0].code))
    return min(eligible, key=lambda pair: (pair[1].cost, pair[1].estimated_days if pair[1].estimated_days is not None else 999, pair[0].code))
