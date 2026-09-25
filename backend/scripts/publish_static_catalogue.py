"""Publish a DB-derived catalogue and validated local images to Flutter web files.

Run from backend after product/media review:

    python -m scripts.publish_static_catalogue --output-dir ../mobile/web/catalogue

This prepares Pages assets locally. It does not deploy them or mark a database
version published; both require a separate release step and admin status flow.
"""

from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
import os
import tempfile
import uuid
from pathlib import Path

from PIL import Image
from sqlalchemy import text

from app.config import settings
from app.database import async_session_factory
from scripts.export_static_catalogue import build_snapshot


PUBLIC_MEDIA_PREFIX = "/catalogue/media/"


def _write_atomic(path: Path, contents: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as handle:
            handle.write(contents)
            temp_path = Path(handle.name)
        os.replace(temp_path, path)
    finally:
        if temp_path is not None:
            temp_path.unlink(missing_ok=True)


def _uploaded_media_names(snapshot: dict) -> set[str]:
    urls: list[str] = []
    for product in snapshot["products"]:
        urls.extend(row["url"] for row in product.get("media", []))
    for family in snapshot["families"]:
        if family.get("primary_image"):
            urls.append(family["primary_image"])
        urls.extend(family.get("media", []))
    names: set[str] = set()
    for url in urls:
        if not url.startswith(PUBLIC_MEDIA_PREFIX):
            continue
        name = url[len(PUBLIC_MEDIA_PREFIX):]
        if name != f"{uuid.UUID(name.removesuffix('.jpg'))}.jpg":
            raise ValueError(f"Invalid public media reference: {url}")
        names.add(name)
    return names


def publish_snapshot(snapshot: dict, output_dir: Path, media_dir: Path) -> dict:
    """Write media and immutable snapshot before atomically switching pointer."""
    digest = snapshot["content_sha256"]
    if len(digest) != 64 or any(char not in "0123456789abcdef" for char in digest):
        raise ValueError("Invalid catalogue content hash")
    contents = (json.dumps(snapshot, sort_keys=True, separators=(",", ":"), ensure_ascii=False) + "\n").encode("utf-8")
    # Verify the exporter hash rather than trusting an arbitrary caller.
    canonical = json.dumps(
        {key: value for key, value in snapshot.items() if key != "content_sha256"},
        sort_keys=True, separators=(",", ":"), ensure_ascii=False,
    ).encode("utf-8")
    if hashlib.sha256(canonical).hexdigest() != digest:
        raise ValueError("Catalogue hash does not match content")

    media_files: list[tuple[str, bytes]] = []
    for name in sorted(_uploaded_media_names(snapshot)):
        source = media_dir / name
        if not source.is_file() or source.is_symlink():
            raise FileNotFoundError(f"Published image missing: {name}")
        if source.stat().st_size > 5 * 1024 * 1024:
            raise ValueError(f"Published image has invalid size: {name}")
        raw = source.read_bytes()
        if not raw or len(raw) > 5 * 1024 * 1024:
            raise ValueError(f"Published image has invalid size: {name}")
        with Image.open(source) as image:
            if image.format != "JPEG" or image.width * image.height > 16_000_000 or image.getexif():
                raise ValueError(f"Published image is not a valid sanitized JPEG: {name}")
            image.verify()
        media_files.append((name, raw))

    version_name = f"products-{digest}.json"
    version_path = output_dir / version_name
    if version_path.exists() and version_path.read_bytes() != contents:
        raise ValueError("Immutable catalogue version already exists with different content")
    for name, raw in media_files:
        target = output_dir / "media" / name
        if target.exists() and target.read_bytes() != raw:
            raise ValueError(f"Published media has conflicting bytes: {name}")
    for name, raw in media_files:
        target = output_dir / "media" / name
        if not target.exists():
            _write_atomic(target, raw)
    if not version_path.exists():
        _write_atomic(version_path, contents)

    pointer = {
        "schema_version": snapshot["schema_version"],
        "snapshot": f"/catalogue/{version_name}",
        "content_sha256": digest,
    }
    _write_atomic(
        output_dir / "current.json",
        (json.dumps(pointer, sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8"),
    )
    return pointer


async def _run(output_dir: Path, media_dir: Path) -> dict:
    async with async_session_factory() as db:
        async with db.begin():
            if db.get_bind().dialect.name == "postgresql":
                await db.execute(text("SET TRANSACTION ISOLATION LEVEL REPEATABLE READ, READ ONLY"))
            snapshot = await build_snapshot(db, "/catalogue/media")
    if not snapshot["products"]:
        raise ValueError("No published products; leaving current catalogue unchanged")
    return publish_snapshot(snapshot, output_dir, media_dir)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--media-dir", type=Path, default=Path(settings.PRODUCT_MEDIA_DIR))
    args = parser.parse_args()
    pointer = asyncio.run(_run(args.output_dir, args.media_dir))
    print(f"Published local Pages assets: {pointer['snapshot']}")


if __name__ == "__main__":
    main()
