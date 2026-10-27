"""Run without building Pi: nix derivation show .#app-pi | python3 tests/pi-ai-clients.py."""

import json
import os
import pathlib
import re
import subprocess
import sys
import tempfile

raw = json.load(sys.stdin)
derivation = next(iter(raw.get("derivations", raw).values()))
script = derivation.get("structuredAttrs", derivation["env"])["text"]
assert "https://ai.hummingbird-lake.ts.net" in script
assert "pi-cliproxyapi-api-key" not in script
assert "pi-decide-api-key" not in script
extension = re.search(r"-e (\S*?-pi-decide\.ts)", script)
assert extension, "Pi must load the shipped local decision extension"
source = pathlib.Path(extension[1]).read_text()
assert 'const baseUrl = "https://ai.hummingbird-lake.ts.net/v1";' in source
assert 'apiKey: "$PI_DECIDE_API_KEY"' in source

with tempfile.TemporaryDirectory() as tmp:
    root = pathlib.Path(tmp)
    key = root / "client-key"
    key.write_text("fixture-client-key\n")
    runner = root / "pi"
    runner.write_text(
        "#!/usr/bin/env python3\n"
        "import json, os, pathlib, sys\n"
        "assert os.environ['PI_OFFLINE'] == '1'\n"
        "if sys.argv[1:] in [['--help'], ['--version']]:\n"
        "    print('offline'); sys.exit(0)\n"
        "assert os.environ['CLIPROXYAPI_BASE_URL'] == 'https://ai.hummingbird-lake.ts.net'\n"
        "assert os.environ['CLIPROXYAPI_API_KEY'] == 'fixture-client-key'\n"
        "assert os.environ['PI_DECIDE_API_KEY'] == os.environ['CLIPROXYAPI_API_KEY']\n"
        "assert sys.argv[1] == sys.argv[3] == '-e'\n"
        "assert sys.argv[5:] == ['--print', 'two words']\n"
        "assert pathlib.Path(os.environ['TMPDIR']).is_dir()\n"
        "print(json.dumps(os.environ['TMPDIR']))\n"
    )
    runner.chmod(0o700)
    wrapper = root / "wrapper"
    wrapper.write_text(
        re.sub(r"/nix/store/[^\s\"]+/bin/pi", str(runner), script).replace(
            "/run/secrets/pi-ai-gateway-api-key", str(key)
        )
    )
    subprocess.run(["bash", "-n", str(wrapper)], check=True)
    env = os.environ | {"HOME": tmp, "PI_CODING_AGENT_DIR": str(root / "agent")}
    result = subprocess.check_output(
        ["bash", str(wrapper), "--print", "two words"], env=env, text=True
    )
    assert not pathlib.Path(json.loads(result)).exists(), (
        "private temp directory leaked"
    )
    key.unlink()
    for flag in ["--help", "--version"]:
        assert (
            subprocess.check_output(
                ["bash", str(wrapper), flag], env=env, text=True
            ).strip()
            == "offline"
        )
    result = subprocess.run(
        ["bash", str(wrapper), "--print", "two words"],
        env=env,
        capture_output=True,
        check=False,
    )
    assert result.returncode != 0 and not result.stdout, "missing key must fail closed"
print(
    "PASS: generated Pi wrapper uses one host key for both front doors, private temp cleanup, offline help/version, and fails closed"
)
