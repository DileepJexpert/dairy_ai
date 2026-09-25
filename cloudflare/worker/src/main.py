"""Cloudflare's Python ASGI entrypoint for the compatibility API."""

from workers import asgi

from api import app

Default = asgi.entrypoint(app)
