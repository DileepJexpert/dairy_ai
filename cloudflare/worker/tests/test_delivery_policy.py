"""Nationwide COD defaults, PIN exceptions, and admin authorization."""

from api import app
from test_customer_auth import auth_client, register


BASE = '/api/v1/marketplace'


def test_admin_policy_controls_cod_quote_and_pin_exceptions(auth_client):
    client, conn = auth_client
    registered = register(client).json()
    client.headers['Authorization'] = 'Bearer ' + registered['access_token']
    env = app.state.env
    env.ENVIRONMENT = 'staging'
    env.LIVE_COD_ENABLED = 'true'
    env.TEST_COMMERCE_ENABLED = 'false'
    assert client.get(BASE + '/admin/delivery-policy').status_code == 403
    assert client.put(BASE + '/admin/delivery-policy', json={
        'cod_default_enabled': True, 'delivery_fee_minor': 7500,
    }).status_code == 403
    customer_id = conn.execute("SELECT id FROM customers ORDER BY rowid DESC LIMIT 1").fetchone()[0]
    conn.execute("UPDATE customers SET role='admin' WHERE id=?", (customer_id,))
    response = client.put(BASE + '/admin/delivery-policy', json={
        'cod_default_enabled': True, 'delivery_fee_minor': 7500,
        'free_delivery_above_minor': 100000,
    })
    assert response.status_code == 200, response.text
    assert response.json()['data']['free_delivery_above_minor'] == 100000
    assert response.json()['data']['online_payment_available'] is False
    unchanged_threshold = client.put(BASE + '/admin/delivery-policy', json={
        'cod_default_enabled': True, 'delivery_fee_minor': 7500,
    })
    assert unchanged_threshold.json()['data']['free_delivery_above_minor'] == 100000
    assert client.get(BASE + '/pincode/check?pincode=560001').json()['delivery_fee'] == 75

    create = client.post(BASE + '/admin/pincodes', json={
        'pincode': '560001', 'cod_enabled': False, 'prepaid_enabled': True,
        'city': 'Bengaluru', 'state': 'Karnataka',
    })
    assert create.status_code == 201, create.text
    result = client.get(BASE + '/pincode/check?pincode=560001').json()
    assert result['cod_available'] is False
    assert result['prepaid_policy_enabled'] is True
    assert result['prepaid_available'] is False
    assert client.post(BASE + '/checkout/quote', json={
        'delivery_address_id': 'missing', 'payment_method': 'upi',
    }).status_code == 503
    assert client.post(BASE + '/admin/pincodes', json={
        'pincode': '560001', 'cod_enabled': True,
    }).status_code == 409
    assert client.put(BASE + '/admin/pincodes/560001', json={'cod_enabled': True,
        'delivery_fee_minor': 2500}).status_code == 200
    assert client.get(BASE + '/pincode/check?pincode=560001').json()['delivery_fee'] == 25
    assert client.delete(BASE + '/admin/pincodes/560001').status_code == 200
    assert client.get(BASE + '/pincode/check?pincode=560001').json()['delivery_fee'] == 75
    assert client.get(BASE + '/admin/pincodes').status_code == 200


def test_nationwide_cod_address_quote_uses_policy_not_old_hub_fee(auth_client):
    client, conn = auth_client
    token = register(client).json()['access_token']
    client.headers['Authorization'] = 'Bearer ' + token
    env = app.state.env
    env.ENVIRONMENT = 'staging'
    env.LIVE_COD_ENABLED = 'true'
    env.TEST_COMMERCE_ENABLED = 'false'
    conn.execute('UPDATE delivery_policy SET cod_default_enabled=1, delivery_fee_minor=9900 WHERE id=1')
    conn.execute("INSERT INTO inventory VALUES ('nationwide-item', 'Item', 2, 10000, 'INR', 1, CURRENT_TIMESTAMP)")
    address = client.post(BASE + '/addresses', json={
        'recipient_name': 'Buyer', 'phone': '9876543210', 'address_line1': 'Street',
        'city': 'Mumbai', 'state': 'Maharashtra', 'pincode': '400001',
    })
    assert address.status_code == 201, address.text
    address_id = address.json()['data']['id']
    assert client.post(BASE + '/cart/items', json={
        'product_id': 'nationwide-item', 'quantity': 1,
    }).status_code == 201
    quote = client.post(BASE + '/checkout/quote', json={'delivery_address_id': address_id})
    assert quote.status_code == 200, quote.text
    assert quote.json()['data']['delivery_fee'] == 99
    assert quote.json()['data']['total'] == 199
    conn.execute("INSERT INTO delivery_pincode_rules(pincode,cod_enabled) VALUES('400001',0)")
    assert client.post(BASE + '/checkout/quote', json={'delivery_address_id': address_id}).status_code == 422
    conn.execute("UPDATE delivery_pincode_rules SET cod_enabled=1, delivery_fee_minor=0 WHERE pincode='400001'")
    assert client.post(BASE + '/checkout/quote', json={'delivery_address_id': address_id}).json()['data']['total'] == 100

    # The threshold uses the item subtotal before coupons and applies to both
    # quote and final order, including a PIN-specific delivery fee.
    conn.execute('UPDATE delivery_policy SET free_delivery_above_minor=100000 WHERE id=1')
    conn.execute("UPDATE delivery_pincode_rules SET delivery_fee_minor=9900 WHERE pincode='400001'")
    conn.execute("UPDATE inventory SET price_minor=100000 WHERE product_id='nationwide-item'")
    at_threshold = client.post(BASE + '/checkout/quote', json={'delivery_address_id': address_id})
    assert at_threshold.status_code == 200, at_threshold.text
    assert at_threshold.json()['data']['delivery_fee'] == 99
    conn.execute("UPDATE inventory SET price_minor=100001 WHERE product_id='nationwide-item'")
    over_threshold = client.post(BASE + '/checkout/quote', json={'delivery_address_id': address_id})
    assert over_threshold.status_code == 200, over_threshold.text
    assert over_threshold.json()['data']['delivery_fee'] == 0
    assert over_threshold.json()['data']['total'] == 1000.01
    order = client.post(BASE + '/checkout', json={
        'delivery_address_id': address_id, 'payment_method': 'cod',
        'idempotency_key': 'nationwide-free-threshold', 'expected_total': 1000.01,
    })
    assert order.status_code == 201, order.text
    assert order.json()['data']['delivery_fee'] == 0
    assert order.json()['data']['total'] == 1000.01
