"""Real HTTP acceptance; creates one synthetic customer and prints its cleanup ID.

No password, session token or real personal details are printed. Operator must
remove the reported synthetic customer after remote testing.
"""
import argparse
import json
import secrets
import urllib.error
import urllib.request
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("--base-url", default="http://127.0.0.1:8791")
parser.add_argument("--origin", default=None)
args = parser.parse_args()


def call(path, body=None, token=None):
    headers = {"Content-Type": "application/json", "User-Agent": "Milterra-Authentication-Acceptance/1.0"}
    if args.origin:
        headers["Origin"] = args.origin
    if token:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(args.base_url + "/api/v1/auth" + path,
        data=json.dumps(body).encode() if body is not None else None, headers=headers)
    try:
        with urllib.request.urlopen(request, timeout=45) as response:
            return response.status, json.loads(response.read())
    except urllib.error.HTTPError as error:
        # Limit error output: never echo submitted inputs or credentials.
        print(f"HTTP failure: {path}: {error.code}")
        try:
            detail = json.loads(error.read()).get("detail")
            if error.code >= 500 and isinstance(detail, str):
                print(detail)
        except (ValueError, AttributeError):
            pass
        return error.code, {}


suffix = uuid.uuid4().hex[:12]
password = secrets.token_urlsafe(24)
phone = "9" + str(secrets.randbelow(10**9)).zfill(9)
username = "runtime." + suffix
status, pair = call("/register-password", {"phone": phone, "password": password,
    "username": username, "email": f"{suffix}@example.invalid", "display_name": "Runtime acceptance test"})
assert status == 201, f"Registration: HTTP {status}"
status, profile = call("/me", token=pair["access_token"])
assert status == 200
print("Synthetic customer for cleanup:", profile["data"]["id"], flush=True)
assert profile["data"]["name"] == "Runtime acceptance test"
status, logged_in = call("/login-password", {"identifier": username, "password": password})
assert status == 200, f"Login: HTTP {status}"
assert call("/login-password", {"identifier": username, "password": "intentionally-wrong-password"})[0] == 401
status, updated = call("/refresh", {"refresh_token": logged_in["refresh_token"]})
assert status == 200
assert call("/refresh", {"refresh_token": logged_in["refresh_token"]})[0] == 401
assert call("/me", token=logged_in["access_token"])[0] == 401
assert call("/me", token=updated["data"]["access_token"])[0] == 200
assert call("/logout", {"refresh_token": updated["data"]["refresh_token"]})[0] == 200
assert call("/me", token=updated["data"]["access_token"])[0] == 401
assert call("/logout", {"refresh_token": pair["refresh_token"]})[0] == 200
print("PASS: register, profile, login, wrong password, atomic refresh/replay, logout/revocation")
