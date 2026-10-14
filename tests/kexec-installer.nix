# Kexec a running machine into the fleet's RAM installer and prove that the
# installer keeps the machine's Tailscale identity and SSH host key.
{
  pkgs,
  nixos-images-src,
  installer,
}:
pkgs.testers.runNixOSTest {
  name = "kexec-installer";
  nodes.machine = {
    virtualisation = {
      vlans = [ ];
      memorySize = 3072;
      forwardPorts = [
        {
          host.port = 2222;
          guest.port = 22;
        }
      ];
    };
    system.extraDependencies = [ installer ];
    services.openssh.enable = true;
    services.tailscale.enable = true;
    # A raw kexec bypasses ExecStop. Require the real shutdown path to stop
    # a running service before entering the installer kernel.
    systemd.services.kexec-shutdown-witness = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        StandardOutput = "journal+console";
        ExecStop = "${pkgs.coreutils}/bin/echo KEXEC_WITNESS_STOPPED";
      };
    };
    users.users.root.openssh.authorizedKeys.keyFiles = [
      "${nixos-images-src}/nix/kexec-installer/ssh-keys/id_ed25519.pub"
    ];
  };
  testScript = ''
    import datetime
    import pathlib
    import subprocess

    import base64
    import secrets

    machine_key = "grep -o '\"_machinekey\": *\"[^\"]*\"' /var/lib/tailscale/tailscaled.state"

    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("kexec-shutdown-witness.service")
    # An offline tailscaled makes no machine key until it logs in, so give it
    # a known one, as a real host would already have.
    seeded = base64.b64encode(b"privkey:" + secrets.token_hex(32).encode()).decode()
    machine.succeed("systemctl stop tailscaled")
    machine.succeed(f"echo '{{\"_machinekey\":\"{seeded}\"}}' > /var/lib/tailscale/tailscaled.state")
    machine.succeed("systemctl start tailscaled")
    machine.wait_for_unit("tailscaled.service")
    machine.wait_until_succeeds(machine_key)
    key_before = machine.succeed(machine_key).strip()
    host_key_before = machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()

    known = pathlib.Path("known-hosts").resolve()
    known.write_text("[127.0.0.1]:2222 " + host_key_before + "\n")
    identity = pathlib.Path("client-key").resolve()
    identity.write_bytes(pathlib.Path("${nixos-images-src}/nix/kexec-installer/ssh-keys/id_ed25519").read_bytes())
    identity.chmod(0o600)

    def ssh(*args, check=True):
        return subprocess.run([
            "${pkgs.openssh}/bin/ssh", "-F", "/dev/null",
            "-o", "StrictHostKeyChecking=yes", "-o", f"UserKnownHostsFile={known}",
            "-o", "BatchMode=yes", "-o", "ConnectTimeout=2",
            "-i", str(identity),
            "-p", "2222", "root@127.0.0.1", *args,
        ], check=check, capture_output=True, text=True)

    machine.succeed("touch /run/old-kernel-marker")
    machine.succeed("tar -xf ${installer}/nixos-kexec-installer-noninteractive-*.tar.gz -C /root")
    machine.succeed("/root/kexec/run")
    machine.wait_for_console_text("KEXEC_WITNESS_STOPPED", timeout=180)
    machine.wait_for_console_text("nixos-installer", timeout=180)
    retry(lambda _: ssh("test ! -e /run/old-kernel-marker", check=False).returncode == 0,
          timeout=datetime.timedelta(seconds=180))

    assert ssh("hostname").stdout.strip() == "nixos-installer"
    retry(lambda _: ssh("systemctl is-active tailscaled", check=False).stdout.strip() == "active",
          timeout=datetime.timedelta(seconds=60))
    key_after = ssh(machine_key).stdout.strip()
    assert key_after == key_before, f"Tailscale machine key changed: {key_before} -> {key_after}"

    # The RAM installer does not contain the test-driver shell. Shut it down
    # over SSH so driver cleanup never uses that shell.
    ssh("poweroff", check=False)
    machine.wait_for_shutdown()
  '';
}
