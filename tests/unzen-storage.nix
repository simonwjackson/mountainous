# Exercise the real initial layout on disposable virtual disks, never hardware.
{ pkgs, diskoLib }:
diskoLib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "unzen-storage";
  disko-config = ../disks/unzen.nix;
  extraInstallerConfig.boot.supportedFilesystems = [ "bcachefs" ];
  extraTestScript = ''
    import json
    import pathlib
    import subprocess

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
    machine.succeed("blkid -s TYPE -o value /dev/vdb1 | grep -Fx vfat")
    machine.fail("mountpoint /boot-secondary")
    machine.succeed("bcachefs fs usage /")
    machine.succeed("bcachefs fs failure-domains /")
    machine.succeed("printf 'shared-pool-marker' > /srv/unzen-test-marker")
    machine.succeed("sync")
    exposure = json.loads(machine.succeed("bcachefs fs failure-domains --json /"))
    assert exposure["devices"] == 2 and exposure["offline_devices"] == 0, exposure
    assert exposure["data_bytes"] > 0 and not exposure["separation_violated"], exposure
    machine.wait_for_unit("bcachefs-scrub-root.timer")

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
