"""Shared safety contracts for native service-app operations. No product policy."""
from dataclasses import dataclass
import json
import os
from pathlib import Path
import re
import shlex
import socket
import ssl
import subprocess
import urllib.request


def name(value: str) -> str:
    if not re.fullmatch(r"[a-z][a-z0-9-]*", value):
        raise ValueError("Expected a lowercase host/app/branch component")
    return value


def run(command: list[str], **kwargs) -> str:
    return subprocess.check_output(command, text=True, **kwargs).strip()


def local_host(expected: str, *, root: bool = True) -> None:
    if socket.gethostname() != expected or (root and os.getuid() != 0):
        raise RuntimeError("Wrong execution host or account")


def pinned(repo: Path, sha: str) -> str:
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        raise ValueError("Expected a full tested source SHA")
    if run(["git", "-C", str(repo), "rev-parse", "HEAD"]) != sha:
        raise RuntimeError("Source changed; expected tested SHA")
    if run(["git", "-C", str(repo), "status", "--porcelain", "--untracked-files=all"]):
        raise RuntimeError("Source checkout must be clean")
    return f"git+file://{repo.resolve()}?rev={sha}"


def native(system: str) -> None:
    actual = run(["nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem"])
    if system != actual:
        raise RuntimeError("Refuse foreign-architecture build or remote-store builder hopping")


def build_flags() -> list[str]:
    return ["--max-jobs", "2", "--cores", "4", "--option", "builders", ""]


def package_canary_expression(ref: str, host: str, app: str, system: str, fixture: str) -> str:
    """Pinned plain-Nix deployment; no path flake input or mutable source lookup."""
    from pathlib import PurePosixPath
    path = PurePosixPath(fixture)
    if path.is_absolute() or ".." in path.parts or not path.parts:
        raise ValueError("Fixture must be inside the pinned repository")
    name(host)
    name(app)
    return (
        f"let f = builtins.getFlake {json.dumps(ref)}; in {{ deploy = "
        "f.lib.serviceAppCanaryDeployment { "
        f"host = {json.dumps(host)}; name = {json.dumps(app)}; system = {json.dumps(system)}; "
        f"fixture = f.outPath + {json.dumps('/' + str(path))}; "
        "}; }\n"
    )


def all_units_active(command: list[str], units: list[str]) -> bool:
    # systemctl with multiple units returns success if ANY unit is active.
    return all(subprocess.run(command + ["is-active", "--quiet", unit],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
               for unit in units)


def require_cutover_ready(states: dict[str, bool], profile_exists: bool) -> list[str]:
    if not states or not all(states.values()):
        raise RuntimeError("Refuse cutover: every source unit must already be active")
    if profile_exists:
        raise RuntimeError("Refuse cutover: destination profile already exists")
    return list(states)


def recovery_units(initial: dict[str, bool], destination_stopped: bool) -> list[str]:
    if not destination_stopped:
        raise RuntimeError("STOP: destination not confirmed stopped; source must stay stopped")
    return [unit for unit, active in initial.items() if active]


@dataclass(frozen=True)
class Health:
    url: str
    equals: dict
    identity_key: str | None = None
    status_only: bool = False

    def __post_init__(self):
        if not self.url.startswith(("https://", "http://127.0.0.1:", "http://localhost:")):
            raise ValueError("Health URL must use HTTPS or HTTP loopback")
        if not isinstance(self.equals, dict):
            raise ValueError("Health equality contract must be a JSON object")
        if not isinstance(self.status_only, bool) or (self.status_only and self.equals):
            raise ValueError("Status-only health cannot specify JSON equality fields")

    def read(self) -> dict:
        context = ssl.create_default_context(cafile="/etc/ssl/certs/ca-certificates.crt") if self.url.startswith("https://") else None
        with urllib.request.urlopen(self.url, context=context, timeout=10) as response:
            if self.status_only:
                if response.status != 200:
                    raise RuntimeError("Public health status is not 200")
                return {}
            value = json.load(response)
        return self.validate(value)

    def validate(self, value: dict) -> dict:
        for path, expected in self.equals.items():
            actual = value
            for component in path.split("."):
                actual = actual[component]
            if actual != expected:
                raise RuntimeError("Public health contract is not ready")
        return value


@dataclass(frozen=True)
class SSH:
    host: str
    user: str
    options: tuple[str, ...] = ()

    def command(self, *arguments: str) -> list[str]:
        # One remote command, shell-escaped once; never concatenate shell programs.
        return ["ssh", "-F", "/dev/null", "-o", "BatchMode=yes", "-o",
                "StrictHostKeyChecking=yes", *self.options, f"{self.user}@{self.host}",
                shlex.join(arguments)]

    def read(self, *arguments: str) -> str:
        return run(self.command(*arguments))
