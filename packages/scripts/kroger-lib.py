#!/usr/bin/env python3
"""Kroger API client for King Soopers grocery management."""

import json
import os
import sys
import base64
import time
import http.server
import threading
import urllib.parse
import requests

CONFIG_DIR = os.path.expanduser("~/.config/kroger")
TOKEN_FILE = os.path.join(CONFIG_DIR, "tokens.json")
STORE_FILE = os.path.join(CONFIG_DIR, "store.json")

def _read_secret(env_var, agenix_path, fallback=""):
    """Read secret from env var, agenix file, or fallback."""
    val = os.environ.get(env_var)
    if val:
        return val
    if os.path.exists(agenix_path):
        with open(agenix_path) as f:
            return f.read().strip()
    return fallback

CLIENT_ID = _read_secret("KROGER_CLIENT_ID", "/run/agenix/kroger-client-id")
CLIENT_SECRET = _read_secret("KROGER_CLIENT_SECRET", "/run/agenix/kroger-client-secret")
REDIRECT_URI = "http://localhost:8400/callback"

BASE_URL = "https://api.kroger.com/v1"
AUTH_URL = "https://api.kroger.com/v1/connect/oauth2"

os.makedirs(CONFIG_DIR, exist_ok=True)


def save_json(path, data):
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def load_json(path):
    if os.path.exists(path):
        with open(path) as f:
            return json.load(f)
    return None


def get_client_token(scope="product.compact"):
    """Get a client credentials token (no user auth needed)."""
    creds = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    r = requests.post(f"{AUTH_URL}/token", headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {creds}"
    }, data={
        "grant_type": "client_credentials",
        "scope": scope
    })
    r.raise_for_status()
    data = r.json()
    data["expires_at"] = time.time() + data.get("expires_in", 1800)
    data["type"] = "client"
    return data


def get_user_auth_url():
    """Generate the OAuth2 authorization URL."""
    scope = "cart.basic:write profile.compact product.compact"
    params = urllib.parse.urlencode({
        "scope": scope,
        "response_type": "code",
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
    })
    return f"{AUTH_URL}/authorize?{params}"


def exchange_code(code):
    """Exchange authorization code for user tokens."""
    creds = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    r = requests.post(f"{AUTH_URL}/token", headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {creds}"
    }, data={
        "grant_type": "authorization_code",
        "code": code,
        "redirect_uri": REDIRECT_URI,
    })
    r.raise_for_status()
    data = r.json()
    data["expires_at"] = time.time() + data.get("expires_in", 1800)
    data["type"] = "user"
    save_json(TOKEN_FILE, data)
    return data


def refresh_token():
    """Refresh an expired user token."""
    tokens = load_json(TOKEN_FILE)
    if not tokens or "refresh_token" not in tokens:
        return None
    creds = base64.b64encode(f"{CLIENT_ID}:{CLIENT_SECRET}".encode()).decode()
    r = requests.post(f"{AUTH_URL}/token", headers={
        "Content-Type": "application/x-www-form-urlencoded",
        "Authorization": f"Basic {creds}"
    }, data={
        "grant_type": "refresh_token",
        "refresh_token": tokens["refresh_token"],
    })
    if r.status_code != 200:
        return None
    data = r.json()
    data["expires_at"] = time.time() + data.get("expires_in", 1800)
    data["type"] = "user"
    save_json(TOKEN_FILE, data)
    return data


def get_token(need_user=False):
    """Get a valid token, refreshing if needed."""
    if need_user:
        tokens = load_json(TOKEN_FILE)
        if tokens and tokens.get("type") == "user":
            if time.time() < tokens.get("expires_at", 0) - 60:
                return tokens["access_token"]
            refreshed = refresh_token()
            if refreshed:
                return refreshed["access_token"]
        print("ERROR: No valid user token. Run: kroger.py auth", file=sys.stderr)
        sys.exit(1)
    # Client token for read-only ops
    token_data = get_client_token()
    return token_data["access_token"]


def api_get(path, params=None, need_user=False):
    token = get_token(need_user=need_user)
    r = requests.get(f"{BASE_URL}{path}", headers={
        "Authorization": f"Bearer {token}",
        "Accept": "application/json"
    }, params=params)
    r.raise_for_status()
    return r.json()


def api_put(path, body, need_user=True):
    token = get_token(need_user=need_user)
    r = requests.put(f"{BASE_URL}{path}", headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "application/json"
    }, json=body)
    r.raise_for_status()
    return r.status_code


def cmd_auth():
    """Start OAuth flow with local callback server."""
    auth_code = [None]

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            qs = urllib.parse.urlparse(self.path).query
            params = urllib.parse.parse_qs(qs)
            if "code" in params:
                auth_code[0] = params["code"][0]
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"<h1>Success! You can close this tab.</h1>")
            else:
                self.send_response(400)
                self.end_headers()
                self.wfile.write(b"No code received")
        def log_message(self, *args):
            pass

    server = http.server.HTTPServer(("localhost", 8400), Handler)
    thread = threading.Thread(target=server.handle_request)
    thread.start()

    url = get_user_auth_url()
    print(f"Open this URL to authorize:\n{url}")
    thread.join(timeout=120)
    server.server_close()

    if auth_code[0]:
        tokens = exchange_code(auth_code[0])
        print(f"Authenticated! Token expires at {time.ctime(tokens['expires_at'])}")
    else:
        print("ERROR: No authorization code received", file=sys.stderr)
        sys.exit(1)


def cmd_locations(zip_code, radius=10, limit=5):
    """Search for Kroger/King Soopers locations."""
    data = api_get("/locations", params={
        "filter.zipCode.near": zip_code,
        "filter.radiusInMiles": radius,
        "filter.limit": limit,
        "filter.chain": "KING SOOPERS",
    })
    for loc in data.get("data", []):
        addr = loc.get("address", {})
        print(f"  {loc['locationId']} | {loc.get('name', 'N/A')} | {addr.get('addressLine1', '')} {addr.get('city', '')}")
    return data


def cmd_search(term, location_id=None, limit=10):
    """Search products."""
    params = {"filter.term": term, "filter.limit": limit}
    if location_id:
        params["filter.locationId"] = location_id
    data = api_get("/products", params=params)
    for p in data.get("data", []):
        desc = p.get("description", "N/A")
        upc = p.get("upc", "")
        items = p.get("items", [{}])
        price = ""
        if items and items[0].get("price"):
            pr = items[0]["price"]
            price = f"${pr.get('regular', '?')}"
            if pr.get('promo'):
                price += f" (sale: ${pr['promo']})"
        size = items[0].get("size", "") if items else ""
        print(f"  {upc} | {desc} | {size} | {price}")
    return data


def cmd_cart_add(items):
    """Add items to cart. items = list of {upc, quantity}."""
    body = {"items": [{"upc": i["upc"], "quantity": i.get("quantity", 1)} for i in items]}
    status = api_put("/cart/add", body)
    print(f"Cart updated (HTTP {status})")
    return status


def cmd_profile():
    """Get user profile."""
    data = api_get("/identity/profile", need_user=True)
    print(json.dumps(data, indent=2))
    return data


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: kroger.py <command> [args]")
        print("  auth                    - Authenticate with Kroger")
        print("  locations <zip>         - Find stores")
        print("  search <term> [store]   - Search products")
        print("  cart-add <upc> [qty]    - Add to cart")
        print("  profile                 - Show profile")
        sys.exit(1)

    cmd = sys.argv[1]

    if cmd == "auth":
        cmd_auth()
    elif cmd == "locations":
        cmd_locations(sys.argv[2] if len(sys.argv) > 2 else "80401")
    elif cmd == "search":
        term = sys.argv[2] if len(sys.argv) > 2 else "eggs"
        store = sys.argv[3] if len(sys.argv) > 3 else None
        cmd_search(term, store)
    elif cmd == "cart-add":
        upc = sys.argv[2]
        qty = int(sys.argv[3]) if len(sys.argv) > 3 else 1
        cmd_cart_add([{"upc": upc, "quantity": qty}])
    elif cmd == "profile":
        cmd_profile()
    else:
        print(f"Unknown command: {cmd}")
        sys.exit(1)
