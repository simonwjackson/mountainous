
"""
Withings OAuth2 authorization flow.
Run once to get access + refresh tokens, then withings-sync.sh handles refresh.

Usage: ./withings-auth.py
  1. Opens a URL — log in with your Withings account and authorize
  2. Paste the redirect URL back here
  3. Tokens saved to ~/.config/withings/tokens.json
"""

import http.server
import json
import os
import sys
import threading
import urllib.parse
import urllib.request

CLIENT_ID = open(os.path.expanduser("~/.secrets/withings-client-id")).read().strip()
CLIENT_SECRET = open(os.path.expanduser("~/.secrets/withings-client-secret")).read().strip()
TOKEN_FILE = os.path.expanduser("~/.config/withings/tokens.json")
REDIRECT_URI = "http://localhost:8888/callback"

# Withings OAuth2 endpoints
AUTH_URL = "https://account.withings.com/oauth2_user/authorize2"
TOKEN_URL = "https://wbsapi.withings.net/v2/oauth2"

def get_auth_url():
    params = urllib.parse.urlencode({
        "response_type": "code",
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "scope": "user.metrics",
        "state": "biometrics",
    })
    return f"{AUTH_URL}?{params}"

auth_code = None

class CallbackHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        if "code" in params:
            auth_code = params["code"][0]
            self.send_response(200)
            self.send_header("Content-Type", "text/html")
            self.end_headers()
            self.wfile.write(b"<h1>Success! You can close this tab.</h1>")
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"No code found")
    def log_message(self, format, *args):
        pass

def exchange_code(code):
    data = urllib.parse.urlencode({
        "action": "requesttoken",
        "grant_type": "authorization_code",
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "code": code,
        "redirect_uri": REDIRECT_URI,
    }).encode()
    
    req = urllib.request.Request(TOKEN_URL, data=data, method="POST")
    resp = urllib.request.urlopen(req)
    result = json.loads(resp.read())
    
    if result.get("status") != 0:
        print(f"Error: {result}")
        sys.exit(1)
    
    return result["body"]

def main():
    url = get_auth_url()
    print(f"\n1. Open this URL in your browser:\n\n{url}\n")
    print("2. Log in and authorize the app.")
    print("3. Waiting for callback on localhost:8888...\n")
    
    # Start local server to catch the callback
    server = http.server.HTTPServer(("0.0.0.0", 8888), CallbackHandler)
    server.timeout = 300  # 5 min timeout
    
    while auth_code is None:
        server.handle_request()
    
    server.server_close()
    print(f"Got authorization code: {auth_code[:8]}...")
    
    # Exchange code for tokens
    print("Exchanging for tokens...")
    tokens = exchange_code(auth_code)
    
    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w") as f:
        json.dump(tokens, f, indent=2)
    os.chmod(TOKEN_FILE, 0o600)
    
    print(f"\nTokens saved to {TOKEN_FILE}")
    print(f"User ID: {tokens.get('userid')}")
    print(f"Access token expires in: {tokens.get('expires_in', '?')}s")
    print("Done! You can now run the sync script.")

if __name__ == "__main__":
    main()
