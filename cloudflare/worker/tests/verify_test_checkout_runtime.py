"""Remote developer COD acceptance; leaves a labelled cancelled test order.

No real payment or courier calls. Prints only record IDs, never credentials.
"""
import argparse
import json
import secrets
import urllib.error
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument('--base-url', required=True)
parser.add_argument('--product-id', required=True)
args = parser.parse_args()
token = None


def call(path, body=None, method=None):
    headers = {'Content-Type':'application/json', 'User-Agent':'Milterra-Checkout-Acceptance/1.0', 'Origin':'https://auth-preview.milterra-staging.pages.dev'}
    if token: headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(args.base_url+'/api/v1/'+path,
        data=json.dumps(body).encode() if body is not None else None,
        method=method, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=60) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        print('HTTP', e.code, path, flush=True)
        return e.code, json.loads(e.read())


suffix=uuid.uuid4().hex[:10]
status,pair=call('auth/register-password', {'phone':'9'+str(secrets.randbelow(10**9)).zfill(9),
    'username':'checkout.'+suffix, 'email':suffix+'@example.invalid',
    'password':secrets.token_urlsafe(24), 'display_name':'COD runtime acceptance'})
assert status == 201, status
token=pair['access_token']
customer=call('auth/me')[1]['data']['id']
print('Synthetic customer:',customer,flush=True)
before=call('marketplace/inventory/'+args.product_id)[1]['data']['available_units']
status,created=call('marketplace/addresses', {'recipient_name':'COD Test Only','phone':'9876000932',
    'address_line1':'Synthetic checkout address','village_or_city':'Noida','district':'Gautam Buddha Nagar',
    'state':'Uttar Pradesh','postal_code':'201305','is_default':True})
assert status == 201, (status,created)
address=created['data']['id']
assert call('marketplace/cart/items',{'product_id':args.product_id,'quantity':1})[0] == 201
cart=call('marketplace/cart')[1]['data']
assert cart['items'][0]['current_price'] == cart['items'][0]['price_when_added']
payload={'delivery_address_id':address,'payment_method':'cod'}
status,quote=call('marketplace/orders/checkout/quote',payload)
assert status == 200, (status,quote)
payload.update(idempotency_key='runtime-'+suffix,expected_total=quote['data']['total'])
status,placed=call('marketplace/orders/checkout',payload)
assert status == 201, (status,placed)
order=placed['data']
print('Test order:',order['id'],flush=True)
assert order['is_test_order'] and order['status']=='CONFIRMED' and order['payment_status']=='PENDING'
status,replay=call('marketplace/orders/checkout',payload)
assert status == 200 and replay['data']==order
assert call('marketplace/orders')[1]['data'][0]==order
assert call('marketplace/inventory/'+args.product_id)[1]['data']['available_units']==before-1
status,cancelled=call('marketplace/orders/'+order['id']+'/cancel',{})
assert status==200 and cancelled['data']['status']=='CANCELLED'
assert call('marketplace/orders/'+order['id']+'/cancel',{})[0]==400
assert call('marketplace/inventory/'+args.product_id)[1]['data']['available_units']==before
assert call('auth/logout',{'refresh_token':pair['refresh_token']})[0]==200
assert call('marketplace/cart')[0]==401
print('PASS: authenticated address, cart, quote, checkout, replay, history, cancellation, stock restoration, logout',flush=True)
