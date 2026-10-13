"""Cloudflare's Python ASGI entrypoint for the compatibility API."""

from workers import Request, WorkerEntrypoint, asgi

from api import app


_CITY_HEADER = "x-milterra-cf-city"
_REGION_HEADER = "x-milterra-cf-region"
_COUNTRY_HEADER = "x-milterra-cf-country"
_INTERNAL_GEO_HEADERS = {_CITY_HEADER, _REGION_HEADER, _COUNTRY_HEADER}


def _cf_text(cf, name: str) -> str:
    """Return a bounded string from Cloudflare request metadata."""
    if cf is None:
        return ""
    try:
        value = getattr(cf, name, None)
    except (AttributeError, TypeError):
        return ""
    if value is None:
        return ""
    text = str(value).strip()
    if text.lower() in {"", "null", "undefined"}:
        return ""
    return text[:128]


def _request_with_geo_headers(request):
    """Bridge trusted ``request.cf`` fields into the ASGI request scope.

    workers-py's ASGI adapter currently copies request headers but does not add
    the Cloudflare ``cf`` object to the ASGI scope. Client-provided copies of
    these internal headers are discarded before the edge values are applied.
    """
    headers = {
        str(key).lower(): str(value)
        for key, value in request.headers.items()
        if str(key).lower() not in _INTERNAL_GEO_HEADERS
    }
    cf = request.cf
    for header, attribute in (
        (_CITY_HEADER, "city"),
        (_REGION_HEADER, "region"),
        (_COUNTRY_HEADER, "country"),
    ):
        value = _cf_text(cf, attribute)
        if value:
            headers[header] = value
    return Request(request, headers=headers)


class Default(WorkerEntrypoint):
    async def fetch(self, request):
        enriched_request = _request_with_geo_headers(request)
        if (enriched_request.headers.get("upgrade") or "").lower() == "websocket":
            return await asgi.websocket(app, enriched_request, self.env)
        return await asgi.fetch(app, enriched_request, self.env, self.ctx)
