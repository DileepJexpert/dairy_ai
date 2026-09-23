"""Multi-Currency API — real-time ECB foreign exchange rates via Frankfurter."""
from datetime import datetime, timedelta
import httpx
from fastapi import APIRouter

router = APIRouter(tags=["currency"])

# In-memory cache for 1 hour to keep latency sub-millisecond
_CACHED_RATES: dict = {}
_LAST_FETCH_TIME: datetime | None = None

FALLBACK_RATES = {
    "USD": 0.0104,
    "EUR": 0.0091,
    "GBP": 0.0079,
    "AED": 0.0382,
    "CAD": 0.0147,
    "AUD": 0.0148,
    "SGD": 0.0134,
}


@router.get("/marketplace/currency/rates")
async def get_currency_rates():
    """
    Returns live currency exchange rates from INR using Frankfurter (European Central Bank data).
    Results are cached in-memory for 1 hour.
    """
    global _CACHED_RATES, _LAST_FETCH_TIME

    now = datetime.now()
    if _LAST_FETCH_TIME and (now - _LAST_FETCH_TIME) < timedelta(hours=1) and _CACHED_RATES:
        return {
            "success": True,
            "base": "INR",
            "rates": _CACHED_RATES,
            "source": "cache",
            "last_updated": _LAST_FETCH_TIME.isoformat(),
        }

    try:
        async with httpx.AsyncClient(timeout=4.0, follow_redirects=True) as client:
            resp = await client.get("https://api.frankfurter.app/latest?from=INR")
            if resp.status_code == 200:
                data = resp.json()
                raw_rates = data.get("rates", {})
                rates = {
                    "USD": round(raw_rates.get("USD", FALLBACK_RATES["USD"]), 5),
                    "EUR": round(raw_rates.get("EUR", FALLBACK_RATES["EUR"]), 5),
                    "GBP": round(raw_rates.get("GBP", FALLBACK_RATES["GBP"]), 5),
                    "CAD": round(raw_rates.get("CAD", FALLBACK_RATES["CAD"]), 5),
                    "AUD": round(raw_rates.get("AUD", FALLBACK_RATES["AUD"]), 5),
                    "SGD": round(raw_rates.get("SGD", FALLBACK_RATES["SGD"]), 5),
                    # AED is pegged to USD at 3.6725
                    "AED": round(raw_rates.get("USD", FALLBACK_RATES["USD"]) * 3.6725, 5),
                }
                _CACHED_RATES = rates
                _LAST_FETCH_TIME = now
                return {
                    "success": True,
                    "base": "INR",
                    "rates": rates,
                    "source": "live_ecb",
                    "last_updated": now.isoformat(),
                }
    except Exception:
        pass

    # Return safe fallback if external service is unreachable
    _CACHED_RATES = FALLBACK_RATES
    _LAST_FETCH_TIME = now
    return {
        "success": True,
        "base": "INR",
        "rates": FALLBACK_RATES,
        "source": "fallback",
        "last_updated": now.isoformat(),
    }
