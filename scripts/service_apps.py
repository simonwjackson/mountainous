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


def state_exclusions(root: Path, values: list[str]) -> set[str]:
    """Permit explicitly retained convenience file links, never omit regular state."""
    if not isinstance(values, list) or not all(isinstance(value, str) for value in values):
        raise ValueError("File-link exclusions must be a list of relative paths")
    excluded = set()
    for value in values:
        path = Path(value)
        if path.is_absolute() or not path.parts or ".." in path.parts:
            raise ValueError("File-link exclusions must stay inside the state source")
        source = root / path
        if not source.is_symlink() or not source.is_file():
            raise ValueError("Only existing file symlinks may be excluded; retain all regular state")
        excluded.add(str(path))
    for parent, directories, files in os.walk(root):
        for filename in directories + files:
            path = Path(parent, filename)
            if path.is_symlink() and str(path.relative_to(root)) not in excluded:
                raise ValueError("State sources must not contain undeclared symlinks")
    return excluded


def migration_source_units(primary: list[str], auxiliary: list[str]) -> list[str]:
    """Keep mandatory live servers distinct from possibly inactive jobs/timers."""
    if not isinstance(primary, list) or not primary or not isinstance(auxiliary, list):
        raise ValueError("Explicit source service units are required")
    units = primary + auxiliary
    for unit in units:
        if not isinstance(unit, str) or not re.fullmatch(r"[a-zA-Z0-9_.@-]+\.(service|timer)", unit):
            raise ValueError("Expected safe service/timer source unit names")
    if any(not unit.endswith(".service") for unit in primary) or len(set(units)) != len(units):
        raise ValueError("Primary units must be distinct services; auxiliary units cannot overlap")
    return units


def declared_units(app: str, directory: Path = Path("/etc/service-apps")) -> list[str]:
    """Read the platform's authoritative app unit list; missing metadata fails closed."""
    name(app)
    units = json.loads((directory / (app + ".json")).read_text())
    allowed = ([app + ".service"], [app + ".service", app + "-tsnet.service"])
    if units not in allowed:
        raise ValueError("Invalid installed service-app unit manifest")
    return units


def all_units_active(command: list[str], units: list[str]) -> bool:
    # systemctl with multiple units returns success if ANY unit is active.
    return bool(units) and all(subprocess.run(command + ["is-active", "--quiet", unit],
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
