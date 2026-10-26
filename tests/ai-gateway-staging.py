"""Exercise the generated TOML and the real Squid deny policy, without upstream calls."""

import json
import pathlib
import socket
import subprocess
import sys
import tempfile
import time
import tomllib

proxy_path, toml_path = map(pathlib.Path, sys.argv[1:])
settings = tomllib.loads(toml_path.read_text())
assert settings["listen"] == "127.0.0.1:8420"
assert settings["egress_proxy"] == "http://127.0.0.1:8421"
assert settings["login_keeper"]["url"] == "http://127.0.0.1:8317"
assert "cors" not in json.dumps(settings).lower()
a, b = settings["gateway_keys"]
assert (a["monthly_cap_usd"], a["requests_per_minute"]) == (2, 10)
assert set(a["dialects"]) == {
    "codex",
    "responses",
    "chat_completions",
    "messages",
    "speech",
    "images",
    "systemone",
    "models",
    "quota",
}
assert b["models"] == ["jev"] and b["dialects"] == ["systemone"]
assert b["monthly_cap_usd"] == 0.01
assert settings["systemone_charges"] == {"jev": 0.004, "solar": 0.004}
charge = settings["systemone_charges"]["jev"]
assert 2 * charge <= b["monthly_cap_usd"] < 3 * charge
for model, fixed_charge in settings["systemone_charges"].items():
    assert settings["prices"][model]["request"] == fixed_charge
assert set(settings["providers"]) == {"gemini", "typesafe", "upstage"}
for price in settings["prices"].values():
    assert all(value > 0 for value in price.values())

policy = proxy_path.read_text()
provider_line = next(
    line for line in policy.splitlines() if line.startswith("acl provider ")
)
assert provider_line.split()[2:4] == ["dstdomain", "-n"]
assert set(provider_line.split()[4:]) == {
    "api.elevenlabs.io",
    "api.x.ai",
    "openrouter.ai",
    "api.typesafe.ai",
    "api.upstage.ai",
    "generativelanguage.googleapis.com",
}
assert "http_port 127.0.0.1:8421\n" in policy
assert [line for line in policy.splitlines() if line.startswith("http_access ")] == [
    "http_access deny !loopback_client",
    "http_access deny !connect_method",
    "http_access deny !tls_port",
    "http_access deny !provider",
    "http_access deny non_public",
    "http_access allow loopback_client connect_method tls_port provider",
    "http_access deny all",
]
private_line = next(
    line for line in policy.splitlines() if line.startswith("acl non_public ")
)
assert {
    "10.0.0.0/8",
    "100.64.0.0/10",
    "127.0.0.0/8",
    "169.254.0.0/16",
    "172.16.0.0/12",
    "192.168.0.0/16",
    "::1/128",
    "fc00::/7",
    "fe80::/10",
} <= set(private_line.split()[3:])
assert "memory_cache_shared off\n" in policy
assert "cache_mem 0 MB\n" in policy
assert "cache_log /run/ai-gateway-staging-egress/cache.log\n" in policy
assert "access_log stdio:/run/ai-gateway-staging-egress/access.log\n" in policy
subprocess.run(["squid", "-k", "parse", "-f", str(proxy_path)], check=True)

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    hosts = root / "hosts"
    # Force a permitted provider name to resolve privately. Its CONNECT must
    # still fail. No test sends a request to an external provider.
    hosts.write_text("127.0.0.1 api.typesafe.ai\n")
    test_config = root / "squid.conf"
    test_config.write_text(
        policy.replace("/run/ai-gateway-staging-egress/", f"{root}/")
        + f"\nhosts_file {hosts}\n"
    )
    with (root / "squid.log").open("w+") as log:
        proxy = subprocess.Popen(
            ["squid", "-N", "-f", str(test_config)], cwd=tmp, stdout=log, stderr=log
        )
        try:
            for _ in range(100):
                if proxy.poll() is not None:
                    log.seek(0)
                    raise AssertionError(log.read())
                try:
                    with socket.create_connection(("127.0.0.1", 8421), timeout=0.1):
                        break
                except OSError:
                    time.sleep(0.05)
            else:
                raise AssertionError("proxy did not listen")
            requests = [
                "GET http://api.typesafe.ai/ HTTP/1.1\r\nHost: api.typesafe.ai\r\n",
                *[
                    f"CONNECT {host} HTTP/1.1\r\nHost: {host}\r\n"
                    for host in [
                        "example.com:443",
                        "api.typesafe.ai.evil.example:443",
                        "sub.api.typesafe.ai:443",
                        "api.typesafe.ai:80",
                        "127.0.0.1:443",
                        "169.254.169.254:443",
                        "100.100.100.100:443",
                        "10.0.0.1:443",
                        "192.168.1.1:443",
                        "[::1]:443",
                        "[fe80::1]:443",
                        "api.typesafe.ai:443",  # DNS private-address defense
                    ]
                ],
            ]
            for request in requests:
                with socket.create_connection(("127.0.0.1", 8421), timeout=2) as conn:
                    conn.settimeout(3)
                    conn.sendall((request + "Connection: close\r\n\r\n").encode())
                    # Finish the response before shutdown so Squid can record
                    # the completed denial instead of an aborted transaction.
                    response = b""
                    while chunk := conn.recv(4096):
                        response += chunk
                    assert response.split(b"\r\n", 1)[0].split()[1] == b"403", (
                        request,
                        response,
                    )
            for _ in range(100):
                if (root / "access.log").read_text().count("/403 ") == len(requests):
                    break
                time.sleep(0.05)
            else:
                raise AssertionError("denied requests were not all logged")
        finally:
            proxy.terminate()
            proxy.wait(timeout=10)
    access_log = (root / "access.log").read_text()
    assert access_log.count("/403 ") == len(requests), access_log
    assert "example.com:443" in access_log
    assert "FATAL" not in (root / "cache.log").read_text()
    print(
        f"PASS: generated TOML, proxy parse, {len(requests)} real denied and logged proxy requests"
    )
