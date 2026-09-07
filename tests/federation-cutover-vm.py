# ruff: noqa: F821
# NixOS test-driver injects nodes and subtest bindings.
start_all()
for node in (success, failed, interrupted, securityfailed, releasefailed):
    node.wait_for_unit("multi-user.target")
    node.wait_for_unit("user@1000.service")
    node.wait_for_unit("headscale.service")
    node.wait_for_unit("strfry.service")
    node.succeed("systemctl --version | grep 'systemd 259'")
    node.succeed("cutover-fixture setup", timeout=180)
    node.wait_for_unit("korrid.service")

with subtest("actual primitives refuse stale evidence without changing trust"):
    success.succeed("cutover-fixture boundaries")
    success.succeed("cutover-fixture preflight-review")

with subtest(
    "one supervisor owns normal daemon, local security, relay, commitments, boot and release"
):
    success.succeed("cutover-fixture launch")
    success.wait_until_succeeds(
        "test -e /var/lib/korri-maintenance-isolation/released.json || test -e /var/lib/korri-maintenance-isolation/failure-held.json",
        timeout=400,
    )
    print(
        success.succeed(
            "journalctl -u korri-cutover-supervisor.service -u korrid.service --no-pager"
        )
    )
    print(success.succeed("cutover-fixture phase"))
    success.succeed("test -e /var/lib/korri-maintenance-isolation/released.json")
    success.wait_until_succeeds(
        "systemctl show korri-cutover-supervisor.service -p Result --value | grep -x success && test $(systemctl show korri-cutover-supervisor.service -p ActiveState --value) = inactive"
    )
    success.succeed("cutover-fixture assert-accepted")
    success.succeed("cutover-fixture relay-cache-refuses", timeout=180)
    success.crash()
    success.start()
    success.wait_for_unit("multi-user.target")
    success.wait_for_unit("korrid.service", timeout=90)
    success.succeed("cutover-fixture assert-accepted-boot")
    success.wait_until_succeeds("cutover-fixture check-commitments", timeout=120)

with subtest(
    "failed activation retains trust and surviving supervisor performs explicit secure recovery"
):
    failed.succeed("touch /run/cutover-fixture-fail")
    failed.succeed("cutover-fixture launch")
    failed.wait_for_file(
        "/var/lib/korri-maintenance-isolation/failure-held.json", timeout=240
    )
    failed.succeed("cutover-fixture assert-cut")
    failed.succeed("systemctl is-active korri-cutover-supervisor.service")
    failed.wait_for_file("/run/korri-cutover-recovery.sock", timeout=60)
    failed.succeed("cutover-fixture recovery-client-deaths", timeout=120)
    failed.succeed("cutover-fixture assert-cut")
    failed.succeed("rm /run/cutover-fixture-fail")
    failed.succeed("cutover-fixture recover")
    failed.wait_for_file(
        "/var/lib/korri-maintenance-isolation/secure-recovery-boot.json", timeout=240
    )
    print(failed.succeed("cutover-fixture phase"))
    print(
        failed.succeed(
            "journalctl -u korri-cutover-supervisor.service -u korrid.service --no-pager"
        )
    )
    failed.succeed(
        "test -e /var/lib/korri-maintenance-isolation/secure-recovery-boot.json"
    )
    failed.wait_until_succeeds(
        "test $(systemctl show korri-cutover-supervisor.service -p ActiveState --value) = inactive"
    )
    failed.succeed("cutover-fixture assert-recovery")
    failed.succeed("cutover-fixture check-commitments")
    failed.crash()
    failed.start()
    failed.wait_for_unit("multi-user.target")
    failed.wait_for_unit("user@1000.service")
    failed.succeed("cutover-fixture assert-recovery-boot")
    failed.wait_until_succeeds("cutover-fixture check-commitments", timeout=120)

with subtest("actual candidate readiness failure keeps new owner/trust and all gates"):
    securityfailed.succeed("cutover-fixture launch")
    securityfailed.wait_for_file(
        "/var/lib/korri-maintenance-isolation/failure-held.json", timeout=240
    )
    securityfailed.succeed("cutover-fixture assert-cut")
    securityfailed.succeed(
        "test ! -e /var/lib/korri-maintenance-isolation/local-accepted.json"
    )
    securityfailed.succeed("nft list table inet korri_maintenance_isolation")
    securityfailed.succeed("systemctl is-active korri-cutover-supervisor.service")

with subtest(
    "changed owned guard during actual boot persistence prevents release and remains closed on candidate boot"
):
    releasefailed.succeed("touch /run/cutover-fixture-release-fail")
    releasefailed.succeed("cutover-fixture launch")
    releasefailed.wait_for_file(
        "/var/lib/korri-maintenance-isolation/failure-held.json", timeout=400
    )
    releasefailed.succeed(
        "test -e /var/lib/korri-maintenance-isolation/acceptance.json"
    )
    releasefailed.succeed(
        "test ! -e /var/lib/korri-maintenance-isolation/released.json"
    )
    releasefailed.succeed("cutover-fixture assert-release-failed")
    releasefailed.crash()
    releasefailed.start()
    releasefailed.wait_for_unit("multi-user.target")
    releasefailed.wait_for_unit("user@1000.service")
    releasefailed.succeed("cutover-fixture assert-release-failed-boot")
    releasefailed.wait_until_succeeds("cutover-fixture check-commitments", timeout=120)

with subtest(
    "UID1000 caller loss does not kill root supervisor; receipt-loss reboot stays closed"
):
    interrupted.succeed("touch /run/cutover-fixture-hold")
    interrupted.succeed(
        "systemctl --user --machine=simonwjackson@.host start cutover-caller.service"
    )
    interrupted.wait_for_file("/run/user/1000/cutover-caller-requested")
    interrupted.wait_for_file("/run/cutover-fixture-activation-waiting", timeout=120)
    interrupted.succeed(
        "systemctl --user --machine=simonwjackson@.host kill --signal=KILL cutover-caller.service"
    )
    interrupted.succeed("systemctl is-active korri-cutover-supervisor.service")
    interrupted.succeed("systemctl is-active korri-maintenance-activation.service")
    interrupted.succeed("nft list table inet korri_maintenance_isolation")
    interrupted.crash()
    interrupted.start()
    interrupted.wait_for_unit("multi-user.target")
    interrupted.wait_for_unit("user@1000.service")
    interrupted.succeed("cutover-fixture assert-boot-closed")
    interrupted.wait_until_succeeds("cutover-fixture check-commitments", timeout=120)
