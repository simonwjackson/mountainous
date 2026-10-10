#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p python3 openssl
"""Fail closed unless GitHub admits only the reviewed manual Forgerie workflow."""

import argparse
import base64
import json
import os
import stat
import subprocess
import sys
import time
import urllib.request

ORG = "forgerie"
REPOSITORY = "forgerie/forgerie"
GROUP = "unzen-forgerie-manual"
WORKFLOW = "forgerie/forgerie/.github/workflows/unzen-pilot.yml@refs/heads/main"
API = "https://api.github.com"


def validate_policy(group, repositories):
    checks = {
        "runner group name": group.get("name") == GROUP,
        "selected repository access": group.get("visibility") == "selected",
        "public repository access": group.get("allows_public_repositories") is True,
        "workflow restrictions": group.get("restricted_to_workflows") is True,
        "exact main workflow": group.get("selected_workflows") == [WORKFLOW],
        "one allowed repository": repositories.get("total_count") == 1,
        "Forgerie repository only": [repo.get("full_name") for repo in repositories.get("repositories", [])] == [REPOSITORY],
    }
    failures = [name for name, passed in checks.items() if not passed]
    if failures:
        raise ValueError("Unsafe GitHub runner policy: " + ", ".join(failures))


def request_json(path, token, body=None):
    data = None if body is None else json.dumps(body).encode()
    request = urllib.request.Request(API + path, data=data, headers={
        "Authorization": "Bearer " + token,
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "mountainous-unzen-runner-preflight",
    })
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.load(response)


def encode(value):
    return base64.urlsafe_b64encode(value).rstrip(b"=")


def installation_token(app_id, key_path):
    info = os.stat(key_path)
    if info.st_uid != 0 or stat.S_IMODE(info.st_mode) != 0o400 or not stat.S_ISREG(info.st_mode):
        raise ValueError("The GitHub App key must be a root-owned regular file with mode 0400")
    now = int(time.time())
    header = encode(json.dumps({"alg": "RS256", "typ": "JWT"}).encode())
    payload = encode(json.dumps({"iat": now - 60, "exp": now + 540, "iss": str(app_id)}).encode())
    message = header + b"." + payload
    signature = subprocess.run(
        ["openssl", "dgst", "-sha256", "-sign", key_path], input=message,
        capture_output=True, check=True,
    ).stdout
    jwt = (message + b"." + encode(signature)).decode()
    installation = request_json("/orgs/" + ORG + "/installation", jwt)
    result = request_json("/app/installations/" + str(installation["id"]) + "/access_tokens", jwt, {})
    return result["token"]


def verify_group(token):
    # Search is paginated; absence or an API error never permits registration.
    page = 1
    while True:
        result = request_json(f"/orgs/{ORG}/actions/runner-groups?per_page=100&page={page}", token)
        groups = result["runner_groups"]
        for group in groups:
            if group.get("name") == GROUP:
                repositories = request_json(f"/orgs/{ORG}/actions/runner-groups/{group['id']}/repositories?per_page=100", token)
                validate_policy(group, repositories)
                return group
        if len(groups) < 100:
            raise ValueError("Required restricted runner group does not exist: " + GROUP)
        page += 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-id", type=int, required=True)
    parser.add_argument("--private-key", required=True)
    args = parser.parse_args()
    verify_group(installation_token(args.app_id, args.private_key))
    print("Verified GitHub access policy for the manual Forgerie workflow")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        # Exception messages do not include tokens, private keys, or response bodies.
        print("Runner registration refused: " + str(error), file=sys.stderr)
        sys.exit(1)
