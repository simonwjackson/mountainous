{
  pkgs,
  nixos-images-src,
  installer,
  verifiedTool,
}:
pkgs.testers.runNixOSTest (
  { config, ... }: {
    name = "unzen-installer";
    nodes.machine = {
      virtualisation = {
        vlans = [ ];
        memorySize = 3072;
        diskSize = 4096;
        emptyDiskImages = [ 1024 ];
        forwardPorts = [
          {
            host.port = 2222;
            guest.port = 22;
          }
        ];
      };
      system.extraDependencies = [ installer ];
      services.openssh.enable = true;
      users.users.root.openssh.authorizedKeys.keyFiles = [
        "${nixos-images-src}/nix/kexec-installer/ssh-keys/id_ed25519.pub"
      ];
    };
    testScript = ''
      import datetime
      import pathlib
      import subprocess

      start_all()
      machine.wait_for_unit("multi-user.target")
      key_before = machine.succeed("cat /etc/ssh/ssh_host_ed25519_key.pub").strip()
      known = pathlib.Path("installer-known-hosts").resolve()
      known.write_text("[127.0.0.1]:2222 " + key_before + "\n")
      identity = pathlib.Path("installer-client-key").resolve()
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

      ssh("true")
      # Exercise the actual patched installer, not an imitation of its options.
      # With no trusted host key it must never reach machine-fact gathering.
      denied = subprocess.run([
          "${pkgs.coreutils}/bin/timeout", "--kill-after=2", "8",
          "${verifiedTool}/bin/nixos-anywhere", "--target-host", "root@127.0.0.1",
          "--ssh-port", "2222", "--ssh-option", "UserKnownHostsFile=/dev/null",
          "-i", str(identity),
          "--phases", "kexec", "--kexec", "/nonexistent.tar.gz",
          "--store-paths", "${pkgs.coreutils}", "${config.nodes.machine.system.build.toplevel}",
      ], capture_output=True, text=True, check=False)
      assert denied.returncode != 0
      assert "Host key verification failed" in denied.stderr, denied.stderr
      assert "Gathering machine facts" not in denied.stdout + denied.stderr
      machine.succeed("touch /run/unzen-old-kernel-marker")
      machine.succeed("tar -xf ${installer}/nixos-kexec-installer-noninteractive-x86_64-linux.tar.gz -C /root")
      machine.succeed("/root/kexec/run")
      machine.wait_for_console_text("nixos-installer", timeout=180)
      retry(lambda _: ssh("test ! -e /run/unzen-old-kernel-marker", check=False).returncode == 0,
            timeout=datetime.timedelta(seconds=180))
      assert ssh("hostname").stdout.strip() == "nixos-installer"
      assert ssh("cat /etc/ssh/ssh_host_ed25519_key.pub").stdout.strip() == key_before
      ssh("modprobe bcachefs")
      ssh("bcachefs", "format", "--label=installer-probe", "/dev/vdb")
      ssh("mkdir", "-p", "/mnt/probe")
      ssh("mount", "-t", "bcachefs", "/dev/vdb", "/mnt/probe")
      ssh("touch", "/mnt/probe/installer-works")
      ssh("sync")
      ssh("test", "-f", "/mnt/probe/installer-works")
      ssh("umount", "/mnt/probe")
      # The RAM installer does not contain the original test-driver shell.
      # Shut it down over verified SSH so driver cleanup never uses that shell.
      ssh("poweroff", check=False)
      machine.wait_for_shutdown()
    '';
  }
)
