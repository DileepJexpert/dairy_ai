"""Public telemetry validation and truthful admin analytics projections."""

from __future__ import annotations

from test_commerce import client, d1_db


VISIT = "/api/v1/analytics/visit"
EVENTS = "/api/v1/analytics/events"
SESSION_ID = "sess-analytics-123456"


def _register(client, **overrides):
    payload = {
        "session_id": SESSION_ID,
        "landing_page": "/shop",
        "device_type": "desktop",
        "browser": "Edge",
        "os": "Windows",
        "referrer": "https://google.com/search?q=milterra",
    }
    payload.update(overrides)
    return client.post(
        VISIT,
        json=payload,
        headers={"cf-connecting-ip": "203.0.113.10", "cf-ipcity": "Mumbai", "cf-region": "Maharashtra"},
    )


def test_events_update_real_session_metrics_and_admin_journey(client, d1_db):
    assert _register(client).status_code == 200
    initial = d1_db.conn.execute(
        "SELECT page_views_count, is_bounce FROM analytics_visitor_sessions WHERE session_id=?",
        (SESSION_ID,),
    ).fetchone()
    assert initial == (0, 1)

    first = client.post(EVENTS, json={"events": [
        {"session_id": SESSION_ID, "event_type": "PAGE_VIEW", "page_url": "/shop"},
        {"session_id": SESSION_ID, "event_type": "ADD_TO_CART", "page_url": "/cart",
         "target_id": "product-1", "element_text": "Add item"},
    ]})
    assert first.status_code == 200
    assert first.json()["data"]["processed"] == 2
    assert d1_db.conn.execute(
        "SELECT page_views_count, is_bounce FROM analytics_visitor_sessions WHERE session_id=?",
        (SESSION_ID,),
    ).fetchone() == (1, 1)

    assert client.post(EVENTS, json={"events": [
        {"session_id": SESSION_ID, "event_type": "PAGE_VIEW", "page_url": "/cart"},
    ]}).status_code == 200
    assert d1_db.conn.execute(
        "SELECT page_views_count, is_bounce FROM analytics_visitor_sessions WHERE session_id=?",
        (SESSION_ID,),
    ).fetchone() == (2, 0)

    d1_db.conn.execute("UPDATE customers SET role='admin' WHERE id='user-1'")
    traffic = client.get("/api/v1/admin/ecommerce/analytics/traffic").json()["data"]
    assert traffic["total_visitors"] == 1
    assert traffic["total_page_views"] == 2
    assert traffic["bounce_rate_percent"] == 0.0
    assert traffic["top_cities"] == [
        {"name": "Mumbai", "visitors_count": 1, "percent": 100.0}
    ]

    sessions = client.get("/api/v1/admin/ecommerce/analytics/sessions").json()["data"]
    assert sessions["total_visitors"] == 1
    journey = sessions["sessions"][0]
    assert journey["city"] == "Mumbai"
    assert journey["state"] == "Maharashtra"
    assert journey["device_type"] == "desktop"
    assert journey["browser"] == "Edge"
    assert journey["farthest_stage"] == "CART"
    assert [step["step"] for step in journey["journey_steps"]] == [
        "PAGE_VIEW", "ADD_TO_CART", "PAGE_VIEW"
    ]

    clickstream = client.get("/api/v1/admin/ecommerce/analytics/clickstream").json()["data"]
    assert len(clickstream) == 3
    assert {event["event_type"] for event in clickstream} == {"PAGE_VIEW", "ADD_TO_CART"}


def test_telemetry_rejects_unbounded_or_unregistered_batches(client):
    assert client.post(EVENTS, json={"events": []}).status_code == 422
    too_many = [
        {"session_id": SESSION_ID, "event_type": "PAGE_VIEW", "page_url": f"/p/{i}"}
        for i in range(26)
    ]
    assert client.post(EVENTS, json={"events": too_many}).status_code == 422
    assert client.post(EVENTS, json={"events": [{
        "session_id": SESSION_ID,
        "event_type": "PAGE_VIEW",
        "page_url": "/" + "x" * 600,
    }]}).status_code == 422
    assert client.post(EVENTS, json={"events": [{
        "session_id": SESSION_ID,
        "event_type": "PAGE_VIEW",
        "page_url": "/shop",
    }]}).status_code == 404


def test_telemetry_enforces_origin_body_size_and_ip_rate_limit(client, d1_db):
    assert client.post(VISIT, json={"session_id": SESSION_ID}, headers={
        "origin": "https://attacker.example"
    }).status_code == 403
    oversized = {"session_id": SESSION_ID, "landing_page": "/" + "x" * 70000}
    assert client.post(VISIT, json=oversized).status_code == 413

    assert _register(client).status_code == 200
    d1_db.conn.execute(
        "UPDATE auth_rate_limits SET attempts=60 WHERE bucket IN "
        "(SELECT bucket FROM auth_rate_limits ORDER BY rowid DESC LIMIT 1)"
    )
    assert _register(client).status_code == 429
