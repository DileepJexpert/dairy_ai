"""Pages publication only switches the pointer after all referenced bytes exist."""

import hashlib
import io
import json
import tempfile
import uuid
from pathlib import Path

import pytest
from PIL import Image

from scripts.export_static_catalogue import _media_base_url
from scripts.publish_static_catalogue import publish_snapshot


@pytest.fixture
def tmp_path():
    """Use a workspace temp dir; this Windows host blocks pytest's basetemp."""
    parent = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix=".tmp-static-publish-", dir=parent) as directory:
        path = Path(directory).resolve()
        assert path.is_relative_to(parent)
        yield path


def snapshot_for(url: str) -> dict:
    body = {
        "schema_version": 1,
        "products": [{"id": "product-1", "media": [{"url": url}]}],
        "families": [],
    }
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()
    return {**body, "content_sha256": hashlib.sha256(canonical).hexdigest()}


def test_same_origin_media_prefix_is_safe() -> None:
    assert _media_base_url("/catalogue/media") == "/catalogue/media"
    assert _media_base_url("/catalogue/media/") == "/catalogue/media"
    for bad in ("/catalogue/media/../private", "/catalogue/media?token=x", "//other/catalogue/media"):
        with pytest.raises(ValueError):
            _media_base_url(bad)


def test_publication_writes_versioned_snapshot_and_pointer_last(tmp_path) -> None:
    output = tmp_path / "site" / "catalogue"
    media = tmp_path / "private-media"
    media.mkdir()
    image_id = uuid.uuid4()
    name = f"{image_id}.jpg"
    raw = io.BytesIO()
    Image.new("RGB", (8, 8), "gold").save(raw, format="JPEG")
    (media / name).write_bytes(raw.getvalue())
    snapshot = snapshot_for(f"/catalogue/media/{name}")

    pointer = publish_snapshot(snapshot, output, media)
    assert pointer == {
        "schema_version": 1,
        "snapshot": f"/catalogue/products-{snapshot['content_sha256']}.json",
        "content_sha256": snapshot["content_sha256"],
    }
    assert json.loads((output / "current.json").read_text()) == pointer
    assert json.loads((output / f"products-{snapshot['content_sha256']}.json").read_text()) == snapshot
    assert (output / "media" / name).read_bytes() == raw.getvalue()
    assert publish_snapshot(snapshot, output, media) == pointer


def test_missing_image_preserves_last_good_pointer(tmp_path) -> None:
    output = tmp_path / "catalogue"
    output.mkdir()
    pointer = output / "current.json"
    pointer.write_text('{"snapshot":"/catalogue/previous.json"}\n')
    snapshot = snapshot_for(f"/catalogue/media/{uuid.uuid4()}.jpg")
    with pytest.raises(FileNotFoundError, match="Published image missing"):
        publish_snapshot(snapshot, output, tmp_path)
    assert pointer.read_text() == '{"snapshot":"/catalogue/previous.json"}\n'
    assert not (output / f"products-{snapshot['content_sha256']}.json").exists()


def test_tampered_hash_cannot_be_published(tmp_path) -> None:
    snapshot = snapshot_for("assets/store/example.jpg")
    snapshot["products"][0]["id"] = "tampered"
    with pytest.raises(ValueError, match="hash does not match"):
        publish_snapshot(snapshot, tmp_path / "catalogue", tmp_path)
