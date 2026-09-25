"""Loopback Razorpay-shaped status endpoint for local Worker runtime checks."""

import base64
import hmac
import json
from http.server import BaseHTTPRequestHandler, HTTPServer


EXPECTED_AUTH = "Basic " + base64.b64encode(b"rzp_test_compat:compat-test-secret").decode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != "/v1/payment_links/plink_test":
            self.send_error(404)
            return
        if not hmac.compare_digest(self.headers.get("Authorization", ""), EXPECTED_AUTH):
            self.send_error(401)
            return
        payload = json.dumps({"id": "plink_test", "status": "paid"}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8899), Handler).serve_forever()
