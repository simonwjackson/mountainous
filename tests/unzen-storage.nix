# Exercise the real initial layout on disposable virtual disks, never hardware.
{ pkgs, diskoLib }:
let
  layout = import ../disks/unzen.nix { inherit (pkgs) lib; };
in
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "unzen-storage";
  disko-config = { inherit (layout) disko; };
  # The upstream harness remaps disk paths and replaces its top-level boot
  # attrset. Pass the real boot policy separately so it is not discarded.
  extraSystemConfig = { inherit (layout) boot services; };
  extraInstallerConfig.boot.supportedFilesystems = [ "bcachefs" ];
  # The installed VM boots the installer's images, not its own state directory.
  postDisko = "installed_disk_source = machine";
  extraTestScript = ''
    import json
    import pathlib
    import subprocess
    import types

    machine.wait_for_unit("multi-user.target")
    for mountpoint in ["/", "/home", "/nix", "/srv"]:
        machine.succeed(f"mountpoint {mountpoint}")
        assert machine.succeed(f"findmnt -n -o FSTYPE {mountpoint}").strip() == "bcachefs"

    filesystems = machine.succeed(
        "find /sys/fs/bcachefs -mindepth 1 -maxdepth 1 -type d"
    ).split()
    assert len(filesystems) == 1, filesystems
    fs = filesystems[0]
    members = machine.succeed(f"find {fs} -maxdepth 1 -name 'dev-*' -type d").split()
    assert len(members) == 2, members
    labels = {machine.succeed(f"cat {dev}/label").strip() for dev in members}
    assert labels == {"onboard.kioxia", "onboard.sn770"}, labels
    domains = {machine.succeed(f"cat {dev}/failure_domain").strip() for dev in members}
    assert domains == labels, domains
    for option in ["data_replicas", "metadata_replicas"]:
        assert machine.succeed(f"cat {fs}/options/{option}").strip() == "2"
    machine.succeed("test -f /boot/EFI/BOOT/BOOTX64.EFI")
    machine.succeed("mountpoint /boot-secondary")
    machine.succeed("test -f /boot-secondary/EFI/BOOT/BOOTX64.EFI")
    for bootpath in ["/boot", "/boot-secondary"]:
        machine.succeed(f"test -s {bootpath}/grub/grub.cfg")
        machine.succeed(f"find {bootpath}/kernels -type f | grep .")
    machine.succeed("bcachefs fs usage /")
    machine.succeed("bcachefs fs failure-domains /")
    machine.succeed("printf 'shared-pool-marker' > /srv/unzen-test-marker")
    machine.succeed("sync")
    exposure = json.loads(machine.succeed("bcachefs fs failure-domains --json /"))
    assert exposure["devices"] == 2 and exposure["offline_devices"] == 0, exposure
    assert exposure["data_bytes"] > 0 and not exposure["separation_violated"], exposure
    machine.wait_for_unit("bcachefs-scrub-root.timer")

    # Shut down before cloning. Each fault case starts from its own consistent
    # snapshot, so degraded writes never create a split-brain test fixture.
    healthy = machine
    healthy.shutdown()
    all_disks = disks

    def disks(oldmachine, num_disks):
        if not hasattr(oldmachine, "survivor"):
            return all_disks(oldmachine, num_disks)
        index = oldmachine.survivor
        return [
            "-drive",
            f"file={oldmachine.state_dir}/empty{index}.qcow2,id=survivor,if=none,werror=report",
            "-device", "virtio-blk-pci,drive=survivor",
        ]

    for survivor, bootpath in [(0, "/boot"), (1, "/boot-secondary")]:
        snapshot = pathlib.Path(healthy.state_dir) / f"fault-{survivor}"
        snapshot.mkdir()
        filename = f"empty{survivor}.qcow2"
        subprocess.check_call([
            "${pkgs.qemu_test}/bin/qemu-img", "convert", "-O", "qcow2",
            str(pathlib.Path(installed_disk_source.state_dir) / filename), str(snapshot / filename),
        ])
        fixture = types.SimpleNamespace(state_dir=snapshot, survivor=survivor)
        failed = create_test_machine(oldmachine=fixture, name=f"survivor-{survivor}")
        failed.start()
        failed.wait_for_unit("multi-user.target")
        for mountpoint in ["/", "/home", "/nix", "/srv", bootpath]:
            failed.succeed(f"mountpoint {mountpoint}")
        failed.succeed(f"test -s {bootpath}/grub/grub.cfg")
        assert failed.succeed("cat /srv/unzen-test-marker") == "shared-pool-marker"
        degraded = json.loads(failed.succeed("bcachefs fs failure-domains --json /"))
        assert degraded["devices"] == 2 and degraded["offline_devices"] == 1, degraded
        failed.succeed("printf 'degraded-write' > /srv/degraded-test-marker")
        failed.succeed("sync")
        assert failed.succeed("cat /srv/degraded-test-marker") == "degraded-write"

        # Restore replicas by expanding the mounted degraded pool. The absent
        # original stays absent, just as on Unzen during its Kioxia fault.
        replacement = snapshot / "replacement.qcow2"
        subprocess.check_call([
            "${pkgs.qemu_test}/bin/qemu-img", "create", "-f", "qcow2",
            str(replacement), "4G",
        ])
        response = failed.send_monitor_command(
            f"drive_add 0 file={replacement},id=replacement,if=none,format=qcow2"
        )
        assert "Error" not in response, response
        response = failed.send_monitor_command(
            "device_add virtio-blk-pci,drive=replacement,id=replacement-device"
        )
        assert "Error" not in response, response
        failed.wait_for_file("/dev/vdb")
        failed.succeed(
            "bcachefs device add --label=card.replacement "
            "--failure_domain=pcie-card --durability=1 / /dev/vdb"
        )
        # In 1.39.6, device add accepts failure_domain but does not apply it
        # to the mounted member. Set it through sysfs and verify the value.
        failed.succeed(
            f"${pkgs.python3}/bin/python3 ${./unzen-card-domain.py} {fs} card.replacement"
        )
        expanded = json.loads(failed.succeed("bcachefs fs failure-domains --json /"))
        assert expanded["devices"] == 3 and expanded["offline_devices"] == 1, expanded
        for option in ["data_replicas", "metadata_replicas"]:
            assert failed.succeed(f"cat {fs}/options/{option}").strip() == "2"
        assert failed.succeed("cat /srv/unzen-test-marker") == "shared-pool-marker"
        assert failed.succeed("cat /srv/degraded-test-marker") == "degraded-write"
        failed.succeed("sync")
        # Membership is immediate; reconciliation runs separately. Require
        # surviving every single failure domain before declaring recovery.
        failed.wait_until_succeeds(
            "${pkgs.python3}/bin/python3 ${./unzen-replica-health.py} /",
            timeout=300,
        )
        failed.shutdown()

    # Resume the untouched healthy pair before testing online expansion.
    machine = create_test_machine(oldmachine=installed_disk_source, name="expanded-machine")
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.fail("test -e /srv/degraded-test-marker")
    assert machine.succeed("cat /srv/unzen-test-marker") == "shared-pool-marker"

    # Add a third, independent virtual device after the two-member pool boots.
    # This tests expansion without re-running Disko or changing the OS layout.
    image = pathlib.Path(machine.state_dir) / "future-member.qcow2"
    subprocess.check_call([
        "${pkgs.qemu_test}/bin/qemu-img", "create", "-f", "qcow2", str(image), "1G"
    ])
    response = machine.send_monitor_command(
        f"drive_add 0 file={image},id=future-member,if=none,format=qcow2"
    )
    assert "Error" not in response, response
    response = machine.send_monitor_command(
        "device_add virtio-blk-pci,drive=future-member,id=future-device"
    )
    assert "Error" not in response, response
    machine.wait_for_file("/dev/vdc")
    before = int(machine.succeed("df -B1 --output=size /srv | tail -n 1").strip())
    machine.succeed(
        "bcachefs device add --label=card.test --failure_domain=pcie-card / /dev/vdc"
    )
    machine.succeed(
        f"${pkgs.python3}/bin/python3 ${./unzen-card-domain.py} {fs} card.test"
    )
    members = machine.succeed(f"find {fs} -maxdepth 1 -name 'dev-*' -type d").split()
    assert len(members) == 3, members
    after = int(machine.succeed("df -B1 --output=size /srv | tail -n 1").strip())
    assert after > before, (before, after)
    assert machine.succeed("cat /srv/unzen-test-marker") == "shared-pool-marker"

    # Policy changes are online, but completion of reconciliation is separate.
    machine.succeed("bcachefs set-fs-option --data_replicas=3 --metadata_replicas=3 /")
    for option in ["data_replicas", "metadata_replicas"]:
        assert machine.succeed(f"cat {fs}/options/{option}").strip() == "3"
    assert machine.succeed("cat /srv/unzen-test-marker") == "shared-pool-marker"
    machine.succeed("bcachefs fs usage /")
  '';
}
