#!/usr/bin/env python3
"""Build one overridden flake input and deploy independent application profiles."""

import argparse
import fcntl
import json
import os
import re
import shlex
from pathlib import Path
import subprocess
import time


def read_json(path, default=None):
    return json.loads(path.read_text()) if path.exists() else default


def write_json(path, value):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(value, indent=2) + "\n")
    temporary.replace(path)


def input_ref(original):
    if original["type"] == "github":
        return (
            "github:"
            + original["owner"]
            + "/"
            + original["repo"]
            + ("/" + original["ref"] if "ref" in original else "")
        )
    if original["type"] == "git":
        return (
            "git+"
            + original["url"]
            + ("?ref=" + original["ref"] if "ref" in original else "")
        )
    raise ValueError("Updater requires a GitHub or git flake input")


def require_not_downgrade(previous, selected, compare):
    if previous and compare(previous["version"], selected["version"]) > 0:
        raise ValueError("Refuse automatic application downgrade")
    if previous and selected["lastModified"] < previous["lastModified"]:
        raise ValueError("Refuse older input revision")


def deploy_hosts(hosts, deploy):
    results = {}
    for host in hosts:
        try:
            deploy(host)
            results[host] = {"status": "deployed"}
        except (subprocess.SubprocessError, OSError) as error:
            # Do not persist child output, which may include sensitive environment.
            results[host] = {"status": "failed", "error": type(error).__name__}
    return results


def build_command(system, attribute, flags):
    if system != "x86_64-linux":
        raise ValueError("Native target build transport is not provisioned")
    return [
        "nix",
        "build",
        "--no-link",
        "--print-out-paths",
        "--max-jobs",
        "2",
        "--cores",
        "4",
        "--option",
        "builders",
        "",
        attribute,
        *flags,
    ]


def native_build(attribute, flags, transport, run):
    """Evaluate locally, realize on the named native builder, then fetch to sign.

    The forced SSH command sets bounds on Yari itself. Remote-store build
    options alone cannot prevent that daemon delegating to another builder.
    """
    drv = run(["nix", "eval", attribute + ".drvPath", "--raw", *flags])
    if not re.fullmatch(r"/nix/store/[a-z0-9]{32}-[^/\s]+\.drv", drv):
        raise ValueError("Invalid native build derivation")
    ssh_options = [
        "-F",
        "/dev/null",
        "-i",
        transport["privateKey"],
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=yes",
        "-o",
        "HostKeyAlias=" + transport["alias"],
        "-o",
        "UserKnownHostsFile=" + transport["knownHosts"],
        "-o",
        "GlobalKnownHostsFile=/dev/null",
    ]
    store = "ssh-ng://simon@" + transport["hostName"]
    env = os.environ | {"NIX_SSHOPTS": shlex.join(ssh_options)}
    run(["nix", "copy", "--derivation", "--to", store, drv], env=env)
    result = run(
        [
            "ssh",
            *ssh_options,
            "simon@" + transport["hostName"],
            "app-native-build " + drv,
        ],
        timeout=7200,
    )
    outputs = result.splitlines()
    if not outputs or not all(
        re.fullmatch(r"/nix/store/[a-z0-9]{32}-[^/\s]+", p) for p in outputs
    ):
        raise ValueError("Invalid native build output")
    # These are our native builder's outputs, not third-party substitutes.
    # They are signed locally only after all candidate checks have passed.
    run(["nix", "copy", "--no-check-sigs", "--from", store, *outputs], env=env)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, required=True)
    parser.add_argument("--app", required=True)
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    os.umask(0o077)
    config = read_json(args.config)
    app = config["apps"][args.app]
    root = Path(config["stateDirectory"])
    repo = root / "repository"
    root.mkdir(mode=0o700, parents=True, exist_ok=True)
    receipts = root / "receipts"
    receipts.mkdir(mode=0o700, exist_ok=True)

    command_log = receipts / (str(time.time_ns()) + ".log")

    def run(command, timeout=3600, env=None):
        result = subprocess.run(
            command, cwd=repo, text=True, capture_output=True, timeout=timeout, env=env
        )
        with command_log.open("a") as log:
            log.write(json.dumps(command) + "\n" + result.stdout + result.stderr + "\n")
        result.check_returncode()
        return result.stdout.strip()

    with (root / "update.lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        receipt = {
            "app": args.app,
            "started_at": int(time.time()),
            "system_deployment": False,
            "hosts": {},
            "status": "started",
            "command_log": str(command_log),
        }
        output = receipts / (str(time.time_ns()) + ".json")
        try:
            if run(["git", "status", "--porcelain", "--untracked-files=all"]):
                raise ValueError("Updater checkout must be clean")
            if app.get("sourceBranch"):
                run(["git", "fetch", "origin", app["sourceBranch"]])
                run(["git", "merge-base", "--is-ancestor", "HEAD", "FETCH_HEAD"])
                run(["git", "checkout", "--detach", "FETCH_HEAD"])
            receipt["source_commit"] = run(["git", "rev-parse", "HEAD"])
            locked = read_json(repo / "flake.lock")
            node = locked["nodes"][locked["root"]]["inputs"][app["input"]]
            original = locked["nodes"][node]["original"]
            metadata = json.loads(
                run(
                    [
                        "nix",
                        "flake",
                        "metadata",
                        "--refresh",
                        "--json",
                        input_ref(original),
                    ]
                )
            )
            selected = metadata["locked"]
            # The exact revision (not a moving branch) is reused for every build.
            ref = metadata["url"]
            flags = [
                "--override-input",
                app["input"],
                ref,
                "--no-write-lock-file",
                "--max-jobs",
                "2",
                "--option",
                "builders",
                "",
            ]
            systems = sorted(
                set(config["hosts"][host] for host in app["hosts"]),
                key=lambda s: s != "x86_64-linux",
            )
            version_attr = f".#packages.{systems[0]}.app-{args.app}.version"
            version = run(["nix", "eval", version_attr, "--raw", *flags])
            baseline = {
                "version": run(
                    ["nix", "eval", version_attr, "--raw", "--no-update-lock-file"]
                ),
                "lastModified": locked["nodes"][node]["locked"]["lastModified"],
            }
            candidate = {
                "version": version,
                "rev": selected["rev"],
                "lastModified": selected["lastModified"],
                "ref": ref,
            }
            accepted_path = root / f"accepted-{args.app}.json"
            accepted = read_json(accepted_path, baseline)

            def compare(old, new):
                return int(
                    run(
                        [
                            "nix",
                            "eval",
                            "--expr",
                            f"builtins.compareVersions {json.dumps(old)} {json.dumps(new)}",
                        ]
                    )
                )

            require_not_downgrade(baseline, candidate, compare)
            require_not_downgrade(accepted, candidate, compare)
            receipt["candidate"] = candidate
            # Build each architecture independently. A builder outage must not
            # prevent x86 hosts from receiving the checked x86 closure.
            builds = {}
            activations = {}
            for system in systems:
                transport = config.get("nativeBuilders", {}).get(system)
                if system != "x86_64-linux" and transport is None:
                    builds[system] = "blocked-native-build-transport"
                    continue
                try:

                    def build(attribute, timeout=7200):
                        if system == "x86_64-linux":
                            return run(
                                build_command(system, attribute, flags), timeout=timeout
                            )
                        return native_build(attribute, flags, transport, run)

                    build(f".#checks.{system}.app-{args.app}")
                    for check in app.get("checks", []):
                        build(f".#checks.{system}.{check}")
                    build(f".#checks.{system}.deploy-schema")
                    representative = next(
                        h for h in app["hosts"] if config["hosts"][h] == system
                    )
                    activation = build(
                        f".#deploy.nodes.{representative}.profiles.{args.app}.path"
                    ).splitlines()[-1]
                    activations[system] = activation
                    builds[system] = "checked"
                except (subprocess.SubprocessError, OSError, ValueError) as error:
                    builds[system] = type(error).__name__
            receipt["builds"] = builds
            receipt["activations"] = activations
            if args.check_only:
                receipt["status"] = (
                    "checks-passed"
                    if all(v == "checked" for v in builds.values())
                    else "checks-failed"
                )
                return 0 if receipt["status"] == "checks-passed" else 1

            for activation in activations.values():
                run(
                    [
                        "nix",
                        "store",
                        "sign",
                        "--recursive",
                        "--key-file",
                        str(root / "signing-key"),
                        activation,
                    ]
                )

            def deploy(host):
                if builds[config["hosts"][host]] != "checked":
                    raise subprocess.SubprocessError("architecture build failed")
                # deploy-rs' default checks are flake-wide: always bypass them.
                run(
                    [
                        "deploy",
                        f".#{host}.{args.app}",
                        "--skip-checks",
                        "--checksigs",
                        "--auto-rollback",
                        "true",
                        "--magic-rollback",
                        "true",
                        "--",
                        *flags,
                    ],
                    timeout=1800,
                )

            receipt["hosts"] = deploy_hosts(app["hosts"], deploy)
            successes = [
                h
                for h, result in receipt["hosts"].items()
                if result["status"] == "deployed"
            ]
            # Partial acceptance advances the downgrade floor; failed hosts are
            # retried on every run, including when the revision is unchanged.
            if successes:
                write_json(accepted_path, candidate | {"accepted_at": int(time.time())})
            receipt["status"] = (
                "deployed" if len(successes) == len(app["hosts"]) else "partial-failure"
            )
            return 0 if receipt["status"] == "deployed" else 1
        except (subprocess.SubprocessError, OSError, ValueError, KeyError) as error:
            receipt["status"] = "failed"
            receipt["error"] = type(error).__name__
            return 1
        finally:
            receipt["finished_at"] = int(time.time())
            write_json(output, receipt)
            print(f"app-update: {args.app}: {receipt['status']}; receipt {output}")


if __name__ == "__main__":
    raise SystemExit(main())
