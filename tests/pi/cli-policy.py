"""Guard the real pi CLI startup, not an imported SettingsManager class."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time


def check_policy(cli, settings_file, probe, agent_dir=None):
    expected = json.loads(settings_file.read_text())
    failures = []
    results = {}
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="pi-cli-policy-") as directory:
        root = Path(directory)
        for name, content in [("locked", settings_file.read_bytes()),
                              ("empty", b""), ("missing", None),
                              ("malformed", b"{malformed")]:
            case = root / name
            case.mkdir()
            agent = agent_dir if name == "locked" and agent_dir else case / "agent"
            agent.mkdir(exist_ok=True)
            if not (name == "locked" and agent_dir):
                if content is not None:
                    (agent / "settings.json").write_bytes(content)
                    (agent / "settings.json").chmod(0o444)
            if name == "locked":
                (agent / "settings.json.lock").mkdir(exist_ok=True)
            home, tmp, cwd = case / "home", case / "tmp", case / "cwd"
            for path in [home, tmp, cwd]:
                path.mkdir(mode=0o700)
            output = case / "effective.json"
            # No operator credentials, project settings, user extensions or
            # inference prompts enter this subprocess. All startup IO is local.
            env = {"PATH": os.environ["PATH"], "HOME": str(home), "TMPDIR": str(tmp),
                   "TERM": "dumb", "NO_COLOR": "1", "PI_OFFLINE": "1",
                   "PI_CODING_AGENT_DIR": str(agent),
                   "PI_POLICY_PROVIDER": expected["defaultProvider"],
                   "PI_POLICY_MODEL": expected["defaultModel"], "PI_POLICY_OUTPUT": str(output)}
            command = [str(cli), "--offline", "--mode", "rpc", "--no-session",
                       "--no-extensions", "--no-skills", "--no-prompt-templates",
                       "--no-themes", "--no-context-files", "--no-tools", "-e", str(probe)]
            try:
                result = subprocess.run(command, input="", text=True, capture_output=True,
                                        cwd=cwd, env=env, timeout=20)
                effective = json.loads(output.read_text()) if output.exists() else None
                results[name] = {"exit_code": result.returncode, "effective": effective}
                if name == "locked":
                    if result.returncode != 0 or effective != expected:
                        failures.append(f"locked: CLI exit={result.returncode}, effective settings do not equal the Nix file")
                elif result.returncode == 0:
                    failures.append(f"{name}: CLI accepted invalid global policy (exit 0)")
            except subprocess.TimeoutExpired:
                results[name] = {"timeout": True}
                failures.append(f"{name}: CLI did not stop within 20 seconds")
    return {"failures": failures, "cases": results, "seconds": time.perf_counter() - started}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cli", type=Path)
    parser.add_argument("settings", type=Path)
    parser.add_argument("--agent-dir", type=Path)
    args = parser.parse_args()
    result = check_policy(args.cli.resolve(), args.settings.resolve(),
                          Path(__file__).with_name("cli-probe.ts"), args.agent_dir)
    for name, case in result["cases"].items():
        print(f"CLI policy {name}: exit={case.get('exit_code', 'timeout')}")
    for failure in result["failures"]:
        print(f"CLI policy FAIL: {failure}")
    print(f"CLI policy: {len(result['cases'])} cases in {result['seconds']:.3f}s")
    return bool(result["failures"])


if __name__ == "__main__":
    raise SystemExit(main())
