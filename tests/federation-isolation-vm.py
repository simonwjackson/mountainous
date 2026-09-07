start_all()
machine.wait_for_unit("multi-user.target")
machine.wait_for_unit("user@1000.service")
machine.succeed("systemctl --version | grep 'systemd 259'")
old = machine.succeed("readlink -f /run/current-system").strip()
# Execute the generation's real wrapper, never an arbitrary activation source copy.
activation = machine.succeed(
    f"readlink -f {old}/bin/.switch-to-configuration-wrapped"
).strip()
assert (
    activation
    == "/nix/store/i1d0j73p75qykj8m0bfvi6wk829p0g9p-switch-to-configuration-0.1.0/bin/switch-to-configuration"
), activation
with subtest(
    "root writes gates but authenticates user-manager commands as UID1000:GID100 without supplementary groups"
):
    machine.succeed("isolation-fixture manager-contract")
machine.succeed("isolation-fixture baseline")
user_pid = machine.succeed(
    "systemctl show user@1000.service -p MainPID --value"
).strip()
machine.succeed(
    "ssh -F /dev/null -i /etc/fixture-key -o StrictHostKeyChecking=no root@localhost 'echo management-ok'"
)

with subtest(
    "ordinary runtime masks lose to NixOS units; foreign control masks are never overwritten"
):
    machine.succeed("isolation-fixture ordinary-mask")
    machine.succeed("isolation-fixture preflight-collision")

with subtest(
    "queued system and user jobs are drained, unrelated jobs are not canceled"
):
    machine.succeed("isolation-fixture queue")
    machine.succeed("isolation-fixture close")
    machine.succeed("isolation-fixture assert-closed")
    assert (
        machine.succeed(
            "systemctl show fixture-blocker.service -p ActiveState --value"
        ).strip()
        == "activating"
    )
    assert (
        machine.succeed("systemctl show user@1000.service -p MainPID --value").strip()
        == user_pid
    )

with subtest("independent root supervisor survives loss of its user-session caller"):
    machine.succeed(
        "systemctl --user --machine=operator@.host start fixture-caller.service"
    )
    machine.wait_for_file("/run/user/1000/fixture-caller-requested")
    machine.wait_for_file("/run/fixture-supervisor-ready")
    assert (
        machine.succeed("cat /run/fixture-supervisor-caller").strip()
        == machine.succeed(
            "systemctl --user --machine=operator@.host show fixture-caller.service -p MainPID --value"
        ).strip()
    )
    machine.succeed(
        "systemctl --user --machine=operator@.host kill --signal=KILL fixture-caller.service"
    )
    machine.wait_for_file("/run/fixture-supervisor-done")
    machine.succeed("isolation-fixture assert-management")

with subtest(
    "hung real activation worker cannot release masks; drain kills descendants"
):
    machine.succeed("touch /run/fixture-hang-activation")
    machine.succeed(
        f"systemd-run --unit=korri-maintenance-activation --service-type=exec --property=User=root --property=KillMode=control-group {old}/specialisation/candidate/bin/switch-to-configuration test"
    )
    machine.wait_for_file("/run/fixture-activation-waiting")
    machine.succeed("isolation-fixture own-worker")
    machine.succeed("isolation-fixture refuse-release")
    machine.succeed("isolation-fixture close")
    machine.succeed("isolation-fixture assert-worker-drained")
    machine.succeed("isolation-fixture assert-closed")
    machine.succeed("rm /run/fixture-hang-activation /run/fixture-activation-waiting")

with subtest(
    "hung real user activation and child are drained outside the root worker cgroup"
):
    machine.succeed("touch /run/fixture-hang-user-activation")
    machine.succeed(
        f"systemd-run --unit=korri-maintenance-activation --service-type=exec --property=User=root --property=KillMode=control-group {old}/specialisation/candidate/bin/switch-to-configuration test"
    )
    machine.wait_for_file("/run/user/1000/fixture-user-activation-waiting")
    machine.succeed("isolation-fixture own-worker")
    machine.succeed("isolation-fixture refuse-release")
    machine.succeed("isolation-fixture close")
    machine.succeed("isolation-fixture assert-user-activation-drained")
    machine.succeed("isolation-fixture assert-worker-drained")
    machine.succeed("isolation-fixture assert-worker-retired")
    machine.succeed("rm /run/fixture-hang-user-activation")

with subtest(
    "two true root-worker retries record distinct invocations and retire only finished evidence"
):
    invocations = set()
    for attempt in (1, 2):
        machine.succeed("touch /run/fixture-hang-activation")
        if attempt == 1:
            machine.succeed("touch /run/fixture-fail-activation")
        machine.succeed(
            f"systemd-run --unit=korri-maintenance-activation --service-type=exec --property=User=root --property=KillMode=control-group {old}/specialisation/candidate/bin/switch-to-configuration test"
        )
        machine.wait_for_file("/run/fixture-activation-waiting")
        invocation = machine.succeed(
            "systemctl show korri-maintenance-activation.service -p InvocationID --value"
        ).strip()
        assert invocation not in invocations
        invocations.add(invocation)
        machine.succeed("isolation-fixture own-worker")
        # Let this owned worker finish the generation activation, rather than
        # replacing the API lifecycle with a direct invocation from the driver.
        machine.succeed("touch /run/fixture-release-activation")
        machine.wait_until_succeeds("test ! -e /run/fixture-activation-waiting")
        machine.wait_until_succeeds(
            "systemctl show korri-maintenance-activation.service -p ActiveState --value | grep -Ex '(inactive|failed)'"
        )
        if attempt == 1:
            machine.succeed(
                "systemctl show korri-maintenance-activation.service -p ExecMainStatus --value | grep -vx 0"
            )
            machine.succeed("isolation-fixture retirement-write-failure")
            machine.succeed("rm /run/fixture-fail-activation")
        else:
            machine.succeed(
                "systemctl show korri-maintenance-activation.service -p ExecMainStatus --value | grep -x 0"
            )
        machine.succeed("isolation-fixture close")
        machine.succeed("isolation-fixture assert-worker-retired")
        machine.succeed(
            "rm /run/fixture-hang-activation /run/fixture-release-activation"
        )
        # Failed transient units retain status until reset; this is not evidence
        # retirement and cannot substitute for close() proving the prior worker.
        machine.succeed(
            "systemctl reset-failed korri-maintenance-activation.service || test ! -e /run/systemd/transient/korri-maintenance-activation.service"
        )
    machine.succeed("grep candidate /etc/fixture-generation")
    machine.succeed("isolation-fixture assert-closed")
    machine.succeed(
        "ssh -F /dev/null -i /etc/fixture-key -o StrictHostKeyChecking=no root@localhost 'echo activation-management-ok'"
    )
    machine.succeed("isolation-fixture assert-management")

with subtest("interrupted activation lists remain evidence and prohibit mask release"):
    machine.succeed("isolation-fixture seed-interrupted")
    machine.succeed("isolation-fixture refuse-release")
    # The pinned tool consumes the saved request but returns 4 when its explicit
    # start meets a mask. Only the tool consumes the list; the gate never clears it.
    status, output = machine.execute(
        f"{old}/specialisation/candidate/bin/switch-to-configuration test"
    )
    assert status == 4, (status, output)
    machine.succeed("isolation-fixture close")
    machine.succeed("isolation-fixture assert-closed")
    machine.succeed(f"{old}/specialisation/candidate/bin/switch-to-configuration test")
    machine.succeed("isolation-fixture assert-closed")

with subtest(
    "permit manifest-write failure stays masked in-process and after reopening"
):
    machine.succeed("isolation-fixture permit-write-failure")
    machine.succeed("isolation-fixture assert-failed-permit-reopened")
    # Keep the unknown permit as evidence; only real power loss expires /run.
    machine.crash()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.succeed("isolation-fixture assert-gated")
    machine.succeed("isolation-fixture close")

with subtest("owned mask restoration leaves persistent individual gates effective"):
    machine.succeed("isolation-fixture unmask")
    machine.succeed("isolation-fixture assert-gated")
    machine.succeed("isolation-fixture reject-unmasked-permit")
    machine.succeed("isolation-fixture close")
    machine.succeed("isolation-fixture permit-sunshine")
    machine.succeed("systemctl is-active sunshine.service")
    machine.succeed("isolation-fixture assert-other-gates")

with subtest(
    "old boot discards maintenance permit and runtime masks but keeps all gates"
):
    machine.crash()
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("user@1000.service")
    machine.succeed("grep old /etc/fixture-generation")
    machine.succeed("isolation-fixture assert-gated")
    machine.succeed(
        "ssh -F /dev/null -i /etc/fixture-key -o StrictHostKeyChecking=no root@localhost 'echo reboot-management-ok'"
    )

for generation in ["candidate", "recovery"]:
    with subtest(f"{generation} activation and reboot remain gated"):
        machine.succeed(
            f"{old}/specialisation/{generation}/bin/switch-to-configuration test"
        )
        machine.succeed("isolation-fixture assert-gated")
        machine.succeed(
            f"nix-env -p /nix/var/nix/profiles/system --set {old}/specialisation/{generation}"
        )
        machine.succeed(
            f"{old}/specialisation/{generation}/bin/switch-to-configuration boot"
        )
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("user@1000.service")
        machine.succeed(f"grep {generation} /etc/fixture-generation")
        machine.succeed("isolation-fixture assert-gated")

with subtest(
    "foreign replacement prevents cleanup; exact restoration retains preexisting mask"
):
    machine.succeed("isolation-fixture collision")
    machine.succeed("isolation-fixture restore")
    machine.succeed("isolation-fixture restored")
