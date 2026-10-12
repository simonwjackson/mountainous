# Install the permafrost layout in a VM, boot it twice, and prove that:
#
#   - Tailscale's identity, the SSH host key and machine-id survive a reboot
#   - files written elsewhere in the system root do not
#   - tailscaled cannot run on the empty tmpfs under its mount point
{
  pkgs,
  inputs,
  permafrost,
}:
inputs.disko.lib.testLib.makeDiskoTest {
  inherit pkgs;
  name = "permafrost";
  disko-config = import ../disks/permafrost.nix {
    device = "/dev/vda";
    rootSize = "512M";
  };
  extraSystemConfig = {
    imports = [ permafrost ];
    mountainous.permafrost.device = "/dev/vda";
    services.openssh.enable = true;
    services.tailscale.enable = true;
    environment.systemPackages = [ pkgs.jq ];
  };
  extraTestScript = ''
    import base64
    import secrets

    def settle():
        machine.wait_for_unit("multi-user.target")
        machine.wait_for_unit("sshd.service")
        machine.wait_for_unit("tailscaled.service")
        machine.wait_until_succeeds("jq -e '._machinekey' /var/lib/tailscale/tailscaled.state")

    # An offline tailscaled makes no machine key until it logs in, so give it
    # a known one, as a real host would already have.
    machine.wait_for_unit("multi-user.target")
    seeded = base64.b64encode(b"privkey:" + secrets.token_hex(32).encode()).decode()
    machine.succeed("systemctl stop tailscaled")
    machine.succeed(f"echo '{{\"_machinekey\":\"{seeded}\"}}' > /var/lib/tailscale/tailscaled.state")
    machine.succeed("systemctl start tailscaled")

    def identity():
        return {
            "tailscale": machine.succeed("jq -r '._machinekey' /var/lib/tailscale/tailscaled.state | sha256sum").strip(),
            "host-key": machine.succeed("ssh-keygen -lf /permafrost/etc/ssh/ssh_host_ed25519_key.pub").strip(),
            "machine-id": machine.succeed("cat /etc/machine-id").strip(),
        }

    settle()
    assert machine.succeed("findmnt -no FSTYPE /").strip() == "tmpfs"
    assert "subvol=/@tailscale" in machine.succeed("findmnt -no OPTIONS /var/lib/tailscale")
    assert "/var/lib/tailscale" in machine.succeed("systemctl show -p RequiresMountsFor tailscaled")
    before = identity()
    assert before["tailscale"] == machine.succeed(f"echo {seeded} | sha256sum").strip(), "tailscaled replaced the seeded key"
    machine.succeed("touch /etc/scratch /var/lib/scratch /root/scratch /home/kept")

    machine.shutdown()
    machine.start()
    settle()

    after = identity()
    assert before == after, f"identity changed across reboot: {before} -> {after}"
    machine.fail("test -e /etc/scratch")
    machine.fail("test -e /var/lib/scratch")
    machine.fail("test -e /root/scratch")
    machine.succeed("test -e /home/kept")
    boots = int(machine.succeed("journalctl --list-boots --no-pager | grep -c .").strip())
    assert boots >= 2, f"journal kept {boots} boot(s); /var/log is not persisted"

    # With its subvolume unmounted, starting tailscaled must mount it first.
    # Otherwise tailscaled would mint a new identity on the tmpfs below.
    machine.succeed("systemctl stop tailscaled")
    machine.succeed("umount /var/lib/tailscale")
    machine.fail("test -e /var/lib/tailscale/tailscaled.state")
    machine.succeed("systemctl start tailscaled")
    machine.succeed("findmnt /var/lib/tailscale")
    settle()
    assert identity() == before, "tailscaled started without its subvolume"
  '';
}
