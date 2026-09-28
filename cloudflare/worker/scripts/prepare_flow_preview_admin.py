"""Create one-off, ignored preview admin credentials and D1 SQL locally.

Run only for an isolated flow-preview D1 before exposing its Worker. This
script prints paths, never credentials; the caller applies the SQL explicitly.
"""

from __future__ import annotations

import asyncio
import secrets
import sys
import uuid
from pathlib import Path

WORKER = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(WORKER / "src"))
from customer_auth import hash_password  # noqa: E402


def main() -> None:
    output = WORKER / ".wrangler"
    output.mkdir(exist_ok=True)
    credentials = output / "flow-preview-admin.txt"
    sql_file = output / "flow-preview-admin.sql"
    secret_file = output / "flow-preview-auth-secret.txt"
    if any(path.exists() for path in (credentials, sql_file, secret_file)):
        raise SystemExit("Preview credential files already exist; rotate them deliberately before rerunning")

    password = secrets.token_urlsafe(30)
    auth_secret = secrets.token_urlsafe(48)
    password_hash = asyncio.run(hash_password(password))
    admin_id = str(uuid.uuid4())
    username = "flow.preview.admin"
    sql = f"""UPDATE customers SET is_active=0 WHERE id='admin-9839769808';
INSERT INTO customers(id,phone,full_name,role,is_active)
VALUES('{admin_id}','flow-preview-admin','Flow Preview Admin','admin',1);
INSERT INTO customer_credentials(customer_id,username,email,password_hash)
VALUES('{admin_id}','{username}','flow-preview-admin@example.invalid','{password_hash}');
"""
    sql_file.write_text(sql, encoding="utf-8")
    credentials.write_text(f"Preview admin username: {username}\nPassword: {password}\n", encoding="utf-8")
    secret_file.write_text(auth_secret, encoding="utf-8")
    print("Prepared ignored preview admin SQL and credentials under cloudflare/worker/.wrangler")


if __name__ == "__main__":
    main()
