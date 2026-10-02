"""Tests for Meta WhatsApp API Webhook verification, message processing, bot replies, and mock logging."""

import pytest
from api import app
from test_customer_auth import auth_client, register


BASE = '/api/v1/marketplace'


def test_whatsapp_webhook_verification(auth_client):
    client, _ = auth_client

    # 1. Invalid verify token should fail with 403
    res_bad = client.get(f"{BASE}/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=wrong_token&hub.challenge=123456")
    assert res_bad.status_code == 403

    # 2. Valid token should succeed with challenge
    res_good = client.get(f"{BASE}/whatsapp/webhook?hub.mode=subscribe&hub.verify_token=milterra_whatsapp_secret_token&hub.challenge=987654")
    assert res_good.status_code == 200
    assert res_good.json() == 987654


def test_whatsapp_bot_incoming_messages(auth_client):
    client, conn = auth_client

    # A. Greeting message "Hi"
    payload_hi = {
        "object": "whatsapp_business_account",
        "entry": [{
            "id": "waba_123",
            "changes": [{
                "field": "messages",
                "value": {
                    "contacts": [{"profile": {"name": "Rahul Sharma"}, "wa_id": "919876543210"}],
                    "messages": [{
                        "from": "919876543210",
                        "id": "wamid_1",
                        "type": "text",
                        "text": {"body": "Hi"}
                    }]
                }
            }]
        }]
    }
    res_hi = client.post(f"{BASE}/whatsapp/webhook", json=payload_hi)
    assert res_hi.status_code == 200
    data_hi = res_hi.json()
    assert data_hi["success"] is True
    assert len(data_hi["outgoing"]) == 1
    reply_hi = data_hi["outgoing"][0]["payload"]
    assert reply_hi["type"] == "interactive"
    assert "Rahul" in reply_hi["interactive"]["body"]["text"]

    # B. Pincode query "Do you deliver to 560001?"
    payload_pin = {
        "object": "whatsapp_business_account",
        "entry": [{
            "id": "waba_123",
            "changes": [{
                "field": "messages",
                "value": {
                    "contacts": [{"profile": {"name": "Rahul Sharma"}, "wa_id": "919876543210"}],
                    "messages": [{
                        "from": "919876543210",
                        "id": "wamid_2",
                        "type": "text",
                        "text": {"body": "Do you deliver to pincode 560001?"}
                    }]
                }
            }]
        }]
    }
    res_pin = client.post(f"{BASE}/whatsapp/webhook", json=payload_pin)
    assert res_pin.status_code == 200
    data_pin = res_pin.json()
    reply_pin = data_pin["outgoing"][0]["payload"]
    assert reply_pin["type"] == "text"
    assert "560001" in reply_pin["text"]["body"]

    # C. Products inquiry
    payload_prod = {
        "object": "whatsapp_business_account",
        "entry": [{
            "id": "waba_123",
            "changes": [{
                "field": "messages",
                "value": {
                    "contacts": [{"profile": {"name": "Rahul Sharma"}, "wa_id": "919876543210"}],
                    "messages": [{
                        "from": "919876543210",
                        "id": "wamid_3",
                        "type": "text",
                        "text": {"body": "What products do you have?"}
                    }]
                }
            }]
        }]
    }
    res_prod = client.post(f"{BASE}/whatsapp/webhook", json=payload_prod)
    assert res_prod.status_code == 200
    reply_prod = res_prod.json()["outgoing"][0]["payload"]
    assert "Ghee" in reply_prod["text"]["body"]


def test_whatsapp_send_mock_and_admin_logs(auth_client):
    client, conn = auth_client
    app.state.env.LIVE_COD_ENABLED = "true"
    registered = register(client).json()
    client.headers['Authorization'] = 'Bearer ' + registered['access_token']
    customer_id = conn.execute("SELECT id FROM customers ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    conn.execute("UPDATE customers SET role='admin' WHERE id=?", (customer_id,))

    # Test direct mock message endpoint
    mock_res = client.post(f"{BASE}/whatsapp/send-mock", json={
        "phone": "919839769808",
        "name": "Dileep Kumar",
        "message": "Track order 10042"
    })
    assert mock_res.status_code == 200
    mock_data = mock_res.json()
    assert mock_data["success"] is True
    assert "Order Lookup" in str(mock_data["bot_payload"])

    # Test admin logs endpoint
    logs_res = client.get(f"{BASE}/admin/whatsapp/logs")
    assert logs_res.status_code == 200
    logs_data = logs_res.json()
    assert logs_data["success"] is True
    assert logs_data["count"] > 0
