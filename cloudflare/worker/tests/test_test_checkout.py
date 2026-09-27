"""Actual password-session to checkout contract, without an auth bypass."""
from api import app
from test_customer_auth import auth_client, register


def test_customer_session_checkout_round_trip(auth_client):
    client, conn = auth_client
    pair = register(client).json()
    client.headers['Authorization'] = 'Bearer ' + pair['access_token']
    assert client.get('/api/v1/marketplace/cart').status_code == 503
    app.state.env.TEST_COMMERCE_ENABLED = 'true'
    app.state.env.ENVIRONMENT = 'staging'
    conn.execute("INSERT INTO inventory VALUES ('checkout-test', 'Test item', 3, 12345, 'INR', 1, CURRENT_TIMESTAMP)")
    conn.execute("INSERT OR REPLACE INTO serviceable_pincodes(pincode,city,state,is_serviceable) VALUES ('201305','Noida','Uttar Pradesh',1)")
    address = dict(recipient_name='Test', phone='9876543210', address_line1='Test lane',
                   village_or_city='Noida', district='Gautam Buddha Nagar', state='Uttar Pradesh',
                   postal_code='201305', landmark='Test marker', is_default=True)
    response = client.post('/api/v1/marketplace/addresses', json=address)
    assert response.status_code == 201, response.text
    saved = response.json()['data']
    assert saved['district'] == address['district'] and saved['postal_code'] == '201305'
    assert client.post('/api/v1/marketplace/cart/items', json={'product_id':'checkout-test','quantity':2}).status_code == 201
    item = client.get('/api/v1/marketplace/cart').json()['data']['items'][0]
    assert item['price_when_added'] == item['current_price'] == 123.45
    payload = {'delivery_address_id':saved['id'], 'payment_method':'cod'}
    quote = client.post('/api/v1/marketplace/orders/checkout/quote', json=payload)
    assert quote.status_code == 200, quote.text
    payload.update(idempotency_key='checkout-session-test', expected_total=quote.json()['data']['total'])
    placed = client.post('/api/v1/marketplace/orders/checkout', json=payload)
    assert placed.status_code == 201, placed.text
    order = placed.json()['data']
    assert order['status'] == 'CONFIRMED' and order['payment_status'] == 'PENDING'
    assert order['is_test_order'] is True and order['items'][0]['line_total'] == 246.90
    assert order['address']['district'] == address['district']
    replay = client.post('/api/v1/marketplace/orders/checkout', json=payload)
    assert replay.status_code == 200 and replay.json()['data'] == order
    assert conn.execute("SELECT available_units FROM inventory WHERE product_id='checkout-test'").fetchone()[0] == 1
    assert client.get('/api/v1/marketplace/orders').json()['data'] == [order]
    assert client.put('/api/v1/marketplace/addresses/'+saved['id'], json={'address_line1':'Updated lane'}).status_code == 200
    assert client.delete('/api/v1/marketplace/addresses/'+saved['id']).status_code == 200
    assert client.get('/api/v1/marketplace/orders/'+order['id']).json()['data']['address']['address_line1'] == 'Test lane'
    other = register(client, phone='9876543211', username='other.test', email='other@example.invalid').json()
    other_headers={'Authorization':'Bearer '+other['access_token']}
    assert client.get('/api/v1/marketplace/orders/'+order['id'], headers=other_headers).status_code == 404
    assert client.get('/api/v1/marketplace/orders', headers=other_headers).json()['data'] == []
    cancelled=client.post('/api/v1/marketplace/orders/'+order['id']+'/cancel')
    assert cancelled.status_code == 200 and cancelled.json()['data']['status'] == 'CANCELLED'
    assert client.post('/api/v1/marketplace/orders/'+order['id']+'/cancel').status_code == 400
    assert conn.execute("SELECT available_units FROM inventory WHERE product_id='checkout-test'").fetchone()[0] == 3
    app.state.env.ENVIRONMENT = 'production'
    assert client.get('/api/v1/marketplace/cart').status_code == 503


def test_live_cod_order_is_real_and_restricted_to_confirmed_pincode(auth_client):
    client, conn = auth_client
    token = register(client).json()['access_token']
    client.headers['Authorization'] = 'Bearer ' + token
    env = app.state.env
    env.ENVIRONMENT = 'staging'
    env.TEST_COMMERCE_ENABLED = 'false'
    env.LIVE_COD_ENABLED = 'true'
    env.LIVE_COD_PINCODES = '201305'
    conn.execute("INSERT INTO inventory VALUES ('live-cod-item', 'COD item', 2, 12345, 'INR', 1, CURRENT_TIMESTAMP)")
    conn.execute("INSERT OR REPLACE INTO serviceable_pincodes(pincode,city,state,is_serviceable,delivery_fee_minor) VALUES ('201305','Noida','Uttar Pradesh',1,0)")
    conn.execute("INSERT OR REPLACE INTO serviceable_pincodes(pincode,city,state,is_serviceable,delivery_fee_minor) VALUES ('110001','New Delhi','Delhi',1,4000)")
    assert client.get('/api/v1/marketplace/pincode/check?pincode=201305').json()['is_serviceable'] is True
    assert client.get('/api/v1/marketplace/pincode/check?pincode=110001').json()['is_serviceable'] is False
    assert client.get('/api/v1/marketplace/orders/payment-capabilities').json()['data']['test_mode'] is False

    def save_address(pincode):
        response = client.post('/api/v1/marketplace/addresses', json={
            'recipient_name': 'Customer', 'phone': '9876543210',
            'address_line1': 'Delivery lane', 'city': 'Noida',
            'state': 'Uttar Pradesh', 'pincode': pincode,
        })
        assert response.status_code == 201, response.text
        return response.json()['data']['id']

    allowed = save_address('201305')
    excluded = save_address('110001')
    assert client.post('/api/v1/marketplace/cart/items', json={'product_id': 'live-cod-item', 'quantity': 1}).status_code == 201
    rejected = client.post('/api/v1/marketplace/orders/checkout/quote', json={'delivery_address_id': excluded})
    assert rejected.status_code == 422
    rejected = client.post('/api/v1/marketplace/orders/checkout', json={
        'delivery_address_id': excluded, 'idempotency_key': 'excluded-pincode', 'payment_method': 'cod',
    })
    assert rejected.status_code == 422
    assert conn.execute("SELECT COUNT(*) FROM orders").fetchone()[0] == 0
    assert client.post('/api/v1/marketplace/orders/checkout/quote', json={
        'delivery_address_id': allowed, 'payment_method': 'upi',
    }).status_code == 503

    quote = client.post('/api/v1/marketplace/orders/checkout/quote', json={
        'delivery_address_id': allowed, 'payment_method': 'cod',
    })
    assert quote.status_code == 200, quote.text
    assert quote.json()['data']['delivery_fee'] == 0
    payload = {'delivery_address_id': allowed, 'idempotency_key': 'real-cod-order',
               'payment_method': 'cod', 'expected_total': quote.json()['data']['total']}
    placed = client.post('/api/v1/marketplace/orders/checkout', json=payload)
    assert placed.status_code == 201, placed.text
    order = placed.json()['data']
    assert order['status'] == 'CONFIRMED' and order['payment_status'] == 'PENDING'
    assert order['is_test_order'] is False
    assert conn.execute('SELECT is_test_order FROM orders WHERE id=?', (order['id'],)).fetchone()[0] == 0
    conn.execute("UPDATE serviceable_pincodes SET is_serviceable=0 WHERE pincode='201305'")
    replay = client.post('/api/v1/marketplace/orders/checkout', json=payload)
    assert replay.status_code == 200 and replay.json()['data'] == order
    assert conn.execute("SELECT available_units FROM inventory WHERE product_id='live-cod-item'").fetchone()[0] == 1
    assert client.post('/api/v1/marketplace/orders/' + order['id'] + '/cancel').status_code == 200
    assert conn.execute("SELECT available_units FROM inventory WHERE product_id='live-cod-item'").fetchone()[0] == 2


def test_live_cod_requires_valid_exclusive_configuration(auth_client):
    client, _ = auth_client
    token = register(client).json()['access_token']
    client.headers['Authorization'] = 'Bearer ' + token
    env = app.state.env
    env.ENVIRONMENT = 'staging'
    env.LIVE_COD_ENABLED = 'true'
    env.TEST_COMMERCE_ENABLED = 'false'
    for invalid_pincodes in ('', '201305,invalid', '12345'):
        env.LIVE_COD_PINCODES = invalid_pincodes
        assert client.get('/api/v1/marketplace/cart').status_code == 503
    env.LIVE_COD_PINCODES = '201305'
    env.TEST_COMMERCE_ENABLED = 'true'
    assert client.get('/api/v1/marketplace/cart').status_code == 503
