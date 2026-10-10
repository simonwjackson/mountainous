#!/usr/bin/env nix-shell
#! nix-shell -i python3 -p python3 openssl systemd
"""Bounded, on-demand readiness: local listener and its exact admitted registration."""
import argparse
import importlib.util
import json
import signal
import subprocess
import sys
import time
from pathlib import Path

NAME = "unzen-forgerie"
UNIT = "github-runner-forgerie.service"
REGISTRATION = Path("/var/lib/github-runner/forgerie/.runner")


def validate_listener(service, registration):
    if service.get("ActiveState") != "active" or int(service.get("MainPID", "0")) <= 0:
        raise ValueError("Runner service has no active listener")
    if registration.get("agentName") != NAME or type(registration.get("agentId")) is not int or registration["agentId"] <= 0:
        raise ValueError("Local runner registration is absent or invalid")


def validate_registration(service, registration, remote):
    validate_listener(service, registration)
    runners = remote.get("runners", [])
    if remote.get("total_count") != 1 or len(runners) != 1:
        raise ValueError("Require exactly one runner in the admitted group")
    runner = runners[0]
    if runner.get("id") != registration["agentId"] or runner.get("name") != NAME:
        raise ValueError("GitHub registration does not match the local listener")
    if runner.get("status") != "online":
        raise ValueError("Current runner registration is not online")
    # Busy means a job reached this listener; it is not a readiness error.
    return runner


def listener_state(registration_path=REGISTRATION, command=("systemctl",)):
    result = subprocess.run(
        [*command, "show", UNIT, "-p", "ActiveState,MainPID,NRestarts"],
        capture_output=True, text=True, check=True, timeout=10,
    )
    service = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    if service.get("ActiveState") != "active":
        raise ValueError("Runner service has no active listener; startup errors remain in the journal")
    return service, json.loads(registration_path.read_text(encoding="utf-8-sig"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy-script", type=Path, required=True)
    parser.add_argument("--app-id", type=int, required=True)
    parser.add_argument("--private-key", required=True)
    parser.add_argument("--timeout", type=int, default=180)
    args = parser.parse_args()
    if not 1 <= args.timeout <= 600:
        parser.error("timeout must be between 1 and 600 seconds")
    spec = importlib.util.spec_from_file_location("policy", args.policy_script)
    policy = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(policy)
    def expired(signum, frame):
        raise TimeoutError("Runner readiness deadline elapsed")

    signal.signal(signal.SIGALRM, expired)
    signal.alarm(args.timeout)
    deadline = time.monotonic() + args.timeout
    token = None
    reason = "Runner readiness deadline elapsed"
    while time.monotonic() < deadline:
        try:
            service, registration = listener_state()
            validate_listener(service, registration)
            if token is None:
                token = policy.installation_token(args.app_id, args.private_key)
            group = policy.verify_group(token)
            remote = policy.request_json(f"/orgs/{policy.ORG}/actions/runner-groups/{group['id']}/runners?per_page=100", token)
            runner = validate_registration(service, registration, remote)
            # Reject a listener replacement during the API requests.
            after, current_registration = listener_state()
            if after["MainPID"] != service["MainPID"] or current_registration["agentId"] != registration["agentId"]:
                raise ValueError("Listener changed during readiness observation")
            signal.alarm(0)
            print(json.dumps({"ready": True, "unit": UNIT, "runner_id": runner["id"], "busy": runner.get("busy", False), "group_id": group["id"], "startup_restarts": service.get("NRestarts", "0")}))
            return 0
        except Exception as error:
            # No response bodies, credentials or tokens enter this diagnostic.
            reason = str(error)
        remaining = deadline - time.monotonic()
        if remaining > 0:
            try:
                time.sleep(min(5, remaining))
            except TimeoutError:
                break
    signal.alarm(0)
    print(json.dumps({"ready": False, "unit": UNIT, "reason": reason}), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
