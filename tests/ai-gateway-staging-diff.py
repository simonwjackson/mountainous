"""Regression tests for the production-unit equality guard."""

import copy
import pathlib
import runpy
import sys

header = pathlib.Path(sys.argv[1]).read_text().splitlines()[:2]
assert header == [
    "#!/usr/bin/env nix-shell",
    "#!nix-shell -i python3 -p python3 nix git",
]
script = runpy.run_path(sys.argv[1])
compare = script["compare"]
services = script["NEW_SERVICES"]
secrets = script["NEW_SECRETS"]
before = {
    "units": ["cliproxyapi.service"],
    "unit_texts": {"cliproxyapi.service": "production-unit-text"},
    "services": {
        "cliproxyapi": {
            "ExecStart": "/production/bin/cli-proxy-api",
            "environment": {"HOME": "/production"},
        }
    },
    "secrets": {"litellm-env": {"key": "litellm-env"}},
    "tailnetNames": {"decide": {"backend": "http://127.0.0.1:4000"}},
}
after = copy.deepcopy(before)
after["units"].extend(name + ".service" for name in services)
after["unit_texts"].update(
    {name + ".service": "staging-unit-text" for name in services}
)
after["services"].update({name: {"ExecStart": "/staging"} for name in services})
after["secrets"].update({name: {"key": name} for name in secrets})
after["tailnetNames"]["ai-staging"] = {"backend": "http://127.0.0.1:8420"}
assert compare(before, after)["status"] == "PASS"
for kind, name, field in [
    ("services", "cliproxyapi", "ExecStart"),
    ("services", "cliproxyapi", "environment"),
    ("secrets", "litellm-env", "key"),
    ("tailnetNames", "decide", "backend"),
]:
    changed = copy.deepcopy(after)
    changed[kind][name][field] = "UNEXPECTED"
    assert compare(before, changed)["status"] == "FAIL"
changed = copy.deepcopy(after)
changed["units"].append("unexpected.service")
assert compare(before, changed)["status"] == "FAIL"
changed = copy.deepcopy(after)
changed["units"].remove("cliproxyapi.service")
assert compare(before, changed)["status"] == "FAIL"
print(
    "PASS: production diff guard rejects ExecStart, environment, secret, name, added/removed unit changes"
)

# The production addition cannot change even a staging unit's generated text.
production_services = script["PRODUCTION_SERVICES"]
production_secrets = script["PRODUCTION_SECRETS"]
production = copy.deepcopy(after)
production["units"].extend(name + ".service" for name in production_services)
production["unit_texts"].update(
    {name + ".service": "production-new" for name in production_services}
)
production["services"].update(
    {name: {"ExecStart": "/new"} for name in production_services}
)
production["secrets"].update({name: {"key": name} for name in production_secrets})
production["tailnetNames"]["ai"] = {"backend": "http://127.0.0.1:8430"}
policy = {
    "services": production_services,
    "secrets": production_secrets,
    "tailnets": {"ai"},
}
assert compare(after, production, **policy)["status"] == "PASS"
changed = copy.deepcopy(production)
changed["unit_texts"]["ai-gateway-staging.service"] = "unexpected staging restart"
assert compare(after, changed, **policy)["status"] == "FAIL"

# B must change exactly the three assistant texts, and no other existing unit.
assistants = script["ASSISTANTS"]
for name in assistants:
    production["units"].append(name + ".service")
    production["unit_texts"][name + ".service"] = "before-cutover"
    production["services"][name] = {"ExecStart": "/assistant", "environment": {}}
cutover = copy.deepcopy(production)
for name in assistants:
    cutover["unit_texts"][name + ".service"] = "after-cutover"
policy = {
    "services": set(),
    "secrets": set(),
    "tailnets": set(),
    "changed_services": assistants,
    "changed_texts": {name + ".service" for name in assistants},
}
assert compare(production, cutover, **policy)["status"] == "PASS"
changed = copy.deepcopy(cutover)
changed["unit_texts"]["ai-gateway.service"] = "unexpected"
assert compare(production, changed, **policy)["status"] == "FAIL"
changed = copy.deepcopy(cutover)
changed["unit_texts"]["pi-assistant-laure.service"] = "before-cutover"
assert compare(production, changed, **policy)["status"] == "FAIL"
print(
    "PASS: production-only additions and exact three-assistant unit-text cutover scope"
)

# The new grant's sole permitted declaration change in B is coordinated
# credential rotation. No existing production secret can change.
assistant_key = "ai-gateway-key-assistant-rakku"
production["secrets"][assistant_key]["restartUnits"] = ["ai-gateway.service"]
rotation = copy.deepcopy(production)
for name in assistants:
    rotation["unit_texts"][name + ".service"] = "after-cutover"
rotation["secrets"][assistant_key]["restartUnits"] += [
    name + ".service" for name in assistants
]
assert (
    compare(production, rotation, **policy, assistant_rotation=True)["status"] == "PASS"
)
assert compare(production, rotation, **policy)["status"] == "FAIL"
changed = copy.deepcopy(rotation)
changed["secrets"][assistant_key]["mode"] = "0444"
assert (
    compare(production, changed, **policy, assistant_rotation=True)["status"] == "FAIL"
)
print(
    "PASS: client key rotation is scoped to the gateway and the same three assistants"
)

# Speech may change only the front door and add its key. The reused provider
# secret gains only the front door's rotation hook; its value stays unchanged.
production["secrets"]["elevenlabs-api-key"] = {
    "key": "elevenlabs-api-key",
    "restartUnits": [],
    "mode": "0400",
}
voice = copy.deepcopy(production)
voice["unit_texts"]["ai-gateway.service"] = "with-speech-config-and-credentials"
voice["services"]["ai-gateway"]["ExecStart"] = "/new-speech-config"
voice["secrets"]["ai-gateway-key-voice-zao"] = {"key": "ai-gateway-key-voice-zao"}
voice["secrets"]["elevenlabs-api-key"]["restartUnits"] = ["ai-gateway.service"]
policy = {
    "services": set(),
    "secrets": {"ai-gateway-key-voice-zao"},
    "tailnets": set(),
    "changed_services": {"ai-gateway"},
    "changed_texts": {"ai-gateway.service"},
    "voice_rotation": True,
}
assert compare(production, voice, **policy)["status"] == "PASS"
for unit in [
    "ai-gateway-staging.service",
    "pi-assistant-laure.service",
    "ai-gateway-egress.service",
    "tsnet-proxy-ai.service",
]:
    changed = copy.deepcopy(voice)
    changed["unit_texts"][unit] = "unexpected-restart"
    assert compare(production, changed, **policy)["status"] == "FAIL"
for field, value in [
    ("mode", "0444"),
    ("restartUnits", ["ai-gateway-staging.service"]),
]:
    changed = copy.deepcopy(voice)
    changed["secrets"]["elevenlabs-api-key"][field] = value
    assert compare(production, changed, **policy)["status"] == "FAIL"
changed = copy.deepcopy(voice)
changed["secrets"][assistant_key]["mode"] = "0444"
assert compare(production, changed, **policy)["status"] == "FAIL"
print(
    "PASS: speech scope permits only the front door, new key and provider rotation hook"
)
