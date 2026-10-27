"""Exercise the generated TOML and the real Squid deny policy, without upstream calls."""

import json
import pathlib
import socket
import subprocess
import sys
import tempfile
import time
import tomllib

proxy_path, toml_path = map(pathlib.Path, sys.argv[1:3])
mode = sys.argv[3] if len(sys.argv) > 3 else "staging"
assert mode in {"staging", "production"}
production = mode == "production"
front_port, proxy_port = (8430, 8431) if production else (8420, 8421)
service_name = "ai-gateway" if production else "ai-gateway-staging"
runtime = f"/run/{service_name}-egress"
settings = tomllib.loads(toml_path.read_text())
assert settings["listen"] == f"127.0.0.1:{front_port}"
assert settings["egress_proxy"] == f"http://127.0.0.1:{proxy_port}"
assert settings["login_keeper"]["url"] == "http://127.0.0.1:8317"
assert settings["state_dir"] == f"/var/lib/{service_name}"
credential_dir = f"/run/credentials/{service_name}.service"
assert settings["login_keeper"]["key_file"] == f"{credential_dir}/login-keeper"
assert settings["usage"]["key_file"] == f"{credential_dir}/usage"
assert all(
    key["key_file"].startswith(credential_dir + "/") for key in settings["gateway_keys"]
)
assert "cors" not in json.dumps(settings).lower()
a = settings["gateway_keys"][0]
if production:
    assert len(settings["gateway_keys"]) == 2
    assert a["name"] == "assistant@rakku"
    assert a["models"] == [
        "claude-opus-5-5",
        "gpt-6.1-sol",
        "gemini-3.8-flash-high",
        "gpt-5.6-luna",
    ]
    assert a["dialects"] == ["codex", "models", "responses"]
    assert (a["monthly_cap_usd"], a["requests_per_minute"]) == (0, 600)
    voice = settings["gateway_keys"][1]
    assert voice == {
        "name": "voice@zao",
        "key_file": f"{credential_dir}/voice-zao",
        "models": ["eleven_flash_v2_5"],
        "dialects": ["speech"],
        "monthly_cap_usd": 5,
        "requests_per_minute": 120,
    }
    # The only speech provider is ElevenLabs; no aliases replace voice IDs.
    assert settings["providers"]["elevenlabs"] == {
        "base_url": "https://api.elevenlabs.io",
        "key_file": f"{credential_dir}/elevenlabs",
    }
    assert settings["prices"]["eleven_flash_v2_5"] == {
        "audio_per_million_characters": 40.0,
    }
else:
    assert len(settings["gateway_keys"]) == 2
    b = settings["gateway_keys"][1]
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
    assert "gpt-image-2" in a["models"]
    assert b["models"] == ["jev"] and b["dialects"] == ["systemone"]
    assert b["monthly_cap_usd"] == 0.01
    charge = settings["systemone_charges"]["jev"]
    assert 2 * charge <= b["monthly_cap_usd"] < 3 * charge
assert "gpt-image-2" not in settings["prices"]
assert all(model["id"] != "gpt-image-2" for model in settings["paid_models"])
gemini_images = {
    "gemini-3.1-flash-image",
    "gemini-3.1-flash-image-preview",
    "gemini-3.1-flash-lite-image",
    "gemini-3-pro-image",
    "gemini-3-pro-image-preview",
    "gemini-2.5-flash-image",
}
speech_models = {"eleven_flash_v2_5"} if production else set()
assert {
    model["id"] for model in settings["paid_models"]
} == gemini_images | speech_models
for model in settings["paid_models"]:
    if model["id"] in speech_models:
        assert model == {
            "id": "eleven_flash_v2_5",
            "provider": "elevenlabs",
            "name": "ElevenLabs Flash v2.5",
        }
        continue
    assert model["provider"] == "gemini"
    assert model["input_modalities"] == ["text", "image"]
    assert (model["id"] in a["models"]) != production
    assert settings["prices"][model["id"]]["image_per_unit"] == 1.0
assert settings["systemone_charges"] == {"jev": 0.004, "solar": 0.004}
for model, fixed_charge in settings["systemone_charges"].items():
    assert settings["prices"][model]["request"] == fixed_charge
assert set(settings["providers"]) == {"gemini", "typesafe", "upstage"} | (
    {"elevenlabs"} if production else set()
)
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
assert f"http_port 127.0.0.1:{proxy_port}\n" in policy
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
assert f"cache_log {runtime}/cache.log\n" in policy
assert f"access_log stdio:{runtime}/access.log\n" in policy
subprocess.run(["squid", "-k", "parse", "-f", str(proxy_path)], check=True)

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    hosts = root / "hosts"
    # Force a permitted provider name to resolve privately. Its CONNECT must
    # still fail. No test sends a request to an external provider.
    hosts.write_text("127.0.0.1 api.typesafe.ai\n")
    test_config = root / "squid.conf"
    test_config.write_text(
        policy.replace(f"{runtime}/", f"{root}/") + f"\nhosts_file {hosts}\n"
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
                    with socket.create_connection(
                        ("127.0.0.1", proxy_port), timeout=0.1
                    ):
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
                with socket.create_connection(
                    ("127.0.0.1", proxy_port), timeout=2
                ) as conn:
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
        f"PASS {mode}: generated TOML, proxy parse, {len(requests)} real denied and logged proxy requests"
    )
