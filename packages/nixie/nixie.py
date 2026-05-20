#!/usr/bin/env python3

"""Unified deploy helper for NixOS and nix-on-droid hosts.

Current behavior:
- stdlib-only Python implementation
- CLI shape: ``nixie <build|test|switch|boot> <host[,host...]>``
- hosts are resolved from flake outputs, not manifests
- hosts execute sequentially
- execution stops on the first failure
- child process output streams live
- exact commands are printed before execution
- `switch` and `test` preflight SSH reachability before doing anything
"""

from __future__ import annotations

import argparse
import json
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from typing import Literal, Sequence

ACTIONS = ("build", "test", "switch", "boot")
Platform = Literal["nixos", "droid"]
DROID_REMOTE_PATH = "~/mountainous"
DROID_RSYNC_PATH = "/etc/profiles/per-user/nix-on-droid/bin/rsync"
DROID_NIX_ON_DROID = "/etc/profiles/per-user/nix-on-droid/bin/nix-on-droid"
SSH_BASE = ("ssh",)
RSYNC_SSH = "ssh"
SSH_CHECK_OPTS = ("-o", "BatchMode=yes", "-o", "ConnectTimeout=2")
ONLINE_CHECK_ACTIONS = frozenset({"switch", "test"})


class NixieError(Exception):
    """Raised for user-facing nixie errors."""


@dataclass(frozen=True)
class FlakeOverride:
    name: str
    value: str


@dataclass(frozen=True)
class Invocation:
    action: str
    hosts: tuple[str, ...]
    flake_overrides: tuple[FlakeOverride, ...] = ()
    check_online: bool = True
    sequential: bool = True
    stop_on_failure: bool = True


@dataclass(frozen=True)
class FlakeHosts:
    nixos: frozenset[str]
    droid: frozenset[str]


@dataclass(frozen=True)
class ResolvedHost:
    name: str
    platform: Platform


@dataclass(frozen=True)
class PlannedCommand:
    argv: tuple[str, ...]


@dataclass(frozen=True)
class HostPlan:
    host: ResolvedHost
    requested_action: str
    effective_action: str
    commands: tuple[PlannedCommand, ...]
    warning: str | None = None


@dataclass(frozen=True)
class HostReachability:
    host: ResolvedHost
    online: bool


def parse_hosts(hosts_arg: str) -> tuple[str, ...]:
    parts = [part.strip() for part in hosts_arg.split(",")]
    if not parts or any(not part for part in parts):
        raise argparse.ArgumentTypeError(
            "hosts must be a comma-separated list like 'yari,fuji,usu'"
        )
    return tuple(parts)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="nixie",
        description=(
            "Run a Nix action across one or more hosts. "
            "Hosts are processed sequentially and execution stops on the first failure."
        ),
    )
    parser.add_argument(
        "action",
        choices=ACTIONS,
        help="Action to run for each host.",
    )
    parser.add_argument(
        "hosts",
        type=parse_hosts,
        help="Comma-separated host list, e.g. 'yari,fuji,usu'.",
    )
    parser.add_argument(
        "--no-check-online",
        action="store_false",
        dest="check_online",
        help="Skip default SSH reachability preflight for switch/test.",
    )
    parser.add_argument(
        "--override-input",
        nargs=2,
        action="append",
        metavar=("NAME", "VALUE"),
        default=[],
        help="Pass a Nix flake input override, e.g. --override-input korri path:/src/korri.",
    )
    return parser


def parse_invocation(argv: Sequence[str] | None = None) -> Invocation:
    args = build_parser().parse_args(argv)
    return Invocation(
        action=args.action,
        hosts=args.hosts,
        flake_overrides=tuple(
            FlakeOverride(name=name, value=value)
            for name, value in args.override_input
        ),
        check_online=args.check_online,
        sequential=True,
        stop_on_failure=True,
    )


def flake_override_args(overrides: Sequence[FlakeOverride]) -> tuple[str, ...]:
    return tuple(
        part
        for override in overrides
        for part in ("--override-input", override.name, override.value)
    )


def load_flake_hosts(overrides: Sequence[FlakeOverride] = ()) -> FlakeHosts:
    expr = (
        "let flake = builtins.getFlake (toString ./.); in "
        "{ "
        '  nixos = builtins.attrNames (flake.nixosConfigurations or {}); '
        '  droid = builtins.attrNames (flake.nixOnDroidConfigurations or {}); '
        "}"
    )
    command = [
        "nix",
        "eval",
        *flake_override_args(overrides),
        "--impure",
        "--json",
        "--expr",
        expr,
    ]

    try:
        result = subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
        )
    except FileNotFoundError as exc:
        raise NixieError("'nix' was not found in PATH") from exc
    except subprocess.CalledProcessError as exc:
        message = (exc.stderr or exc.stdout).strip() or "unknown nix evaluation failure"
        raise NixieError(f"failed to query flake hosts: {message}") from exc

    try:
        payload = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise NixieError("failed to parse flake host list from nix eval output") from exc

    return FlakeHosts(
        nixos=frozenset(payload.get("nixos", [])),
        droid=frozenset(payload.get("droid", [])),
    )


def resolve_host(host: str, flake_hosts: FlakeHosts) -> ResolvedHost:
    in_nixos = host in flake_hosts.nixos
    in_droid = host in flake_hosts.droid

    if in_nixos and in_droid:
        raise NixieError(
            f"host '{host}' is ambiguous: present in both nixosConfigurations and nixOnDroidConfigurations"
        )
    if in_nixos:
        return ResolvedHost(name=host, platform="nixos")
    if in_droid:
        return ResolvedHost(name=host, platform="droid")

    raise NixieError(
        f"unknown host '{host}': not found in nixosConfigurations or nixOnDroidConfigurations"
    )


def resolve_hosts(
    hosts: Sequence[str], overrides: Sequence[FlakeOverride] = ()
) -> tuple[ResolvedHost, ...]:
    flake_hosts = load_flake_hosts(overrides)
    return tuple(resolve_host(host, flake_hosts) for host in hosts)


def build_nixos_plan(
    action: str, host: ResolvedHost, overrides: Sequence[FlakeOverride] = ()
) -> HostPlan:
    if host.platform != "nixos":
        raise NixieError(
            f"host '{host.name}' is platform '{host.platform}', not nixos"
        )

    return HostPlan(
        host=host,
        requested_action=action,
        effective_action=action,
        commands=(
            PlannedCommand(
                argv=(
                    "nixos-rebuild",
                    action,
                    "--flake",
                    f".#{host.name}",
                    *flake_override_args(overrides),
                    "--build-host",
                    host.name,
                    "--target-host",
                    host.name,
                    "--sudo",
                )
            ),
        ),
    )


def build_droid_build_plan(
    host: ResolvedHost, overrides: Sequence[FlakeOverride] = ()
) -> HostPlan:
    return HostPlan(
        host=host,
        requested_action="build",
        effective_action="build",
        commands=(
            PlannedCommand(
                argv=(
                    "nix",
                    "build",
                    *flake_override_args(overrides),
                    f".#nixOnDroidConfigurations.{host.name}.activationPackage",
                )
            ),
        ),
    )


def build_droid_switch_plan(
    requested_action: str,
    host: ResolvedHost,
    overrides: Sequence[FlakeOverride] = (),
    warning: str | None = None,
) -> HostPlan:
    return HostPlan(
        host=host,
        requested_action=requested_action,
        effective_action="switch",
        commands=(
            PlannedCommand(
                argv=(
                    *SSH_BASE,
                    host.name,
                    f"mkdir -p {DROID_REMOTE_PATH}",
                )
            ),
            PlannedCommand(
                argv=(
                    "rsync",
                    "-av",
                    "--delete",
                    "--exclude",
                    ".git",
                    "-e",
                    RSYNC_SSH,
                    f"--rsync-path={DROID_RSYNC_PATH}",
                    "./",
                    f"{host.name}:{DROID_REMOTE_PATH}/",
                )
            ),
            PlannedCommand(
                argv=(
                    *SSH_BASE,
                    host.name,
                    (
                        f"cd {DROID_REMOTE_PATH} && "
                        f"{DROID_NIX_ON_DROID} switch --flake .#{host.name} "
                        f"{shlex.join(flake_override_args(overrides))}"
                    ),
                )
            ),
        ),
        warning=warning,
    )


def build_droid_plan(
    action: str, host: ResolvedHost, overrides: Sequence[FlakeOverride] = ()
) -> HostPlan:
    if host.platform != "droid":
        raise NixieError(
            f"host '{host.name}' is platform '{host.platform}', not droid"
        )

    if action == "build":
        return build_droid_build_plan(host, overrides)
    if action == "switch":
        return build_droid_switch_plan("switch", host, overrides)
    if action == "test":
        return build_droid_switch_plan(
            "test",
            host,
            overrides,
            warning=(
                f"droid host '{host.name}' does not support a separate test mode; "
                "treating 'test' as 'switch'"
            ),
        )
    if action == "boot":
        raise NixieError(f"droid host '{host.name}' does not support action 'boot'")

    raise NixieError(f"unsupported droid action '{action}' for host '{host.name}'")


def build_host_plan(
    action: str, host: ResolvedHost, overrides: Sequence[FlakeOverride] = ()
) -> HostPlan:
    if host.platform == "nixos":
        return build_nixos_plan(action, host, overrides)
    if host.platform == "droid":
        return build_droid_plan(action, host, overrides)

    raise NixieError(f"unsupported platform '{host.platform}' for host '{host.name}'")


def build_plans(
    action: str, hosts: Sequence[ResolvedHost], overrides: Sequence[FlakeOverride] = ()
) -> tuple[HostPlan, ...]:
    return tuple(build_host_plan(action, host, overrides) for host in hosts)


def plan_commands(invocation: Invocation) -> tuple[HostPlan, ...]:
    hosts = resolve_hosts(invocation.hosts, invocation.flake_overrides)
    return build_plans(invocation.action, hosts, invocation.flake_overrides)


def format_command(argv: Sequence[str]) -> str:
    return shlex.join(argv)


def should_check_online(action: str) -> bool:
    return action in ONLINE_CHECK_ACTIONS


def probe_host_online(host: ResolvedHost) -> HostReachability:
    command = [*SSH_BASE, *SSH_CHECK_OPTS, host.name, "true"]
    completed = subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return HostReachability(host=host, online=(completed.returncode == 0))


def check_hosts_online(hosts: Sequence[ResolvedHost]) -> tuple[HostReachability, ...]:
    if not hosts:
        return ()

    max_workers = min(32, len(hosts))
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        return tuple(executor.map(probe_host_online, hosts))


def preflight_online_hosts(action: str, hosts: Sequence[ResolvedHost]) -> None:
    if not should_check_online(action):
        return

    print("Checking host reachability...", flush=True)
    statuses = check_hosts_online(hosts)
    online_hosts = [status.host.name for status in statuses if status.online]
    offline_hosts = [status.host.name for status in statuses if not status.online]

    print(f"online: {' '.join(online_hosts) if online_hosts else '(none)'}", flush=True)
    if offline_hosts:
        print(f"offline: {' '.join(offline_hosts)}", flush=True)
        raise NixieError(
            f"refusing to run {action} because some hosts are offline: {', '.join(offline_hosts)}"
        )


def execute_command(command: PlannedCommand) -> int:
    print(f"+ {format_command(command.argv)}", flush=True)
    completed = subprocess.run(command.argv)
    return completed.returncode


def execute_plan(plan: HostPlan) -> None:
    print(
        f"==> {plan.host.name} ({plan.host.platform}) {plan.requested_action}",
        flush=True,
    )
    if plan.warning:
        print(f"warning: {plan.warning}", file=sys.stderr, flush=True)

    for command in plan.commands:
        returncode = execute_command(command)
        if returncode != 0:
            raise NixieError(
                f"host '{plan.host.name}' action '{plan.requested_action}' failed "
                f"while running: {format_command(command.argv)} (exit {returncode})"
            )


def execute_invocation(invocation: Invocation) -> None:
    hosts = resolve_hosts(invocation.hosts, invocation.flake_overrides)
    if invocation.check_online:
        preflight_online_hosts(invocation.action, hosts)
    plans = build_plans(invocation.action, hosts, invocation.flake_overrides)
    for plan in plans:
        execute_plan(plan)


def main(argv: Sequence[str] | None = None) -> int:
    try:
        invocation = parse_invocation(argv)
        execute_invocation(invocation)
    except NixieError as exc:
        print(f"nixie: error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
