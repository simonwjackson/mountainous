"""Make sure the Beszel hub has the read-only login that beszel-mcp uses.

Runs as the hub's user on the hub host. It signs a short-lived superuser token from
the hub database (read-only; the token stays in memory) and goes through the hub's
own API for every write. The login exists afterwards with role `readonly` and the
password from the credential file. A login that already works is left untouched.
"""

import argparse
import base64
import hashlib
import hmac
import json
from pathlib import Path
import sqlite3
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


def b64(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def superuser_token(db_path: Path) -> str:
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    try:
        row = db.execute("SELECT id, tokenKey FROM _superusers ORDER BY created LIMIT 1").fetchone()
        collection_id, options = db.execute(
            "SELECT id, options FROM _collections WHERE name = '_superusers'"
        ).fetchone()
    finally:
        db.close()
    if row is None:
        raise SystemExit("no superuser yet: create the first Beszel account in the web UI")
    secret = json.loads(options)["authToken"]["secret"]
    header = b64(json.dumps({"alg": "HS256", "typ": "JWT"}).encode())
    claims = b64(json.dumps({
        "id": row[0], "type": "auth", "collectionId": collection_id,
        "refreshable": False, "exp": int(time.time()) + 120,
    }).encode())
    signature = hmac.new((row[1] + secret).encode(), f"{header}.{claims}".encode(), hashlib.sha256)
    return f"{header}.{claims}.{b64(signature.digest())}"


class Hub:
    def __init__(self, url: str):
        self.url = url.rstrip("/")

    def call(self, method, path, body=None, auth=None):
        headers = {"Content-Type": "application/json"}
        if auth:
            headers["Authorization"] = auth
        request = urllib.request.Request(
            self.url + path, method=method, headers=headers,
            data=None if body is None else json.dumps(body).encode(),
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status, json.loads(response.read() or b"null")
        except urllib.error.HTTPError as error:
            return error.code, None

    def wait(self, seconds: int) -> None:
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            try:
                if self.call("GET", "/api/health")[0] == 200:
                    return
            except OSError:
                pass
            time.sleep(2)
        raise SystemExit("hub did not answer /api/health")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hub", required=True)
    parser.add_argument("--db", required=True, type=Path)
    parser.add_argument("--email", required=True)
    parser.add_argument("--password-file", required=True, type=Path)
    args = parser.parse_args()
    password = args.password_file.read_text().strip()
    hub = Hub(args.hub)
    hub.wait(90)

    status, login = hub.call("POST", "/api/collections/users/auth-with-password",
                             {"identity": args.email, "password": password})
    if status == 200 and login["record"].get("role") == "readonly":
        print(f"{args.email}: read-only login works; nothing to do")
        return

    auth = superuser_token(args.db)
    query = urllib.parse.urlencode({"filter": f'email="{args.email}"'})
    status, found = hub.call("GET", f"/api/collections/users/records?{query}", auth=auth)
    if status != 200:
        raise SystemExit(f"user lookup failed: HTTP {status}")
    body = {"password": password, "passwordConfirm": password, "role": "readonly", "verified": True}
    if found["items"]:
        status, _ = hub.call("PATCH", f"/api/collections/users/records/{found['items'][0]['id']}",
                             body, auth=auth)
        action = "updated"
    else:
        status, _ = hub.call("POST", "/api/collections/users/records",
                             {"email": args.email, "emailVisibility": False, **body}, auth=auth)
        action = "created"
    if status != 200:
        raise SystemExit(f"{action} failed: HTTP {status}")
    status, login = hub.call("POST", "/api/collections/users/auth-with-password",
                             {"identity": args.email, "password": password})
    if status != 200 or login["record"].get("role") != "readonly":
        raise SystemExit("login check failed after provisioning")
    print(f"{args.email}: {action}, role readonly, login verified")


if __name__ == "__main__":
    sys.exit(main())
