# The real federation and memory-guard modules on three VMs.
#
#   fast   - an always-on builder, speedFactor 1.
#   laptop - a home-gated builder, speedFactor 9, so Nix tries it first. The
#            VM's router is not in homeMacs, so its gate refuses until a
#            manual choice turns it on.
#   client - builds nothing itself (max-jobs 0).
#
# It proves: a refusing builder makes Nix use the next one; a manual choice
# makes the preferred builder accept; a fleet host key may only run the gate;
# the memory guard's settings are live; and oomd ends a cgroup in system.slice
# under sustained memory pressure while SSH keeps answering.
#
# Every key here is nixpkgs' public snakeoil test key, not a fleet key.
{
  pkgs,
  federation,
  memoryGuard,
}:
let
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
  hostKey = keys.snakeOilEd25519PublicKey;
  entry = speedFactor: gate: {
    system = pkgs.stdenv.hostPlatform.system;
    cpus = 2;
    maxJobs = 1;
    inherit speedFactor gate;
    features = [ ];
    sshUser = "simon";
    sshPort = 22;
    inherit hostKey;
    memoryHigh = "60%";
    memoryMax = "70%";
    managed = true;
  };
  fleet = {
    builders = {
      fast = entry 1 "always";
      laptop = entry 9 "home";
    };
    hostKeys = {
      fast = hostKey;
      laptop = hostKey;
      client = hostKey;
    };
    homeMacs = [ "02:00:00:00:00:01" ];
  };
  common =
    { lib, ... }:
    {
      imports = [
        (federation fleet)
        memoryGuard
      ];
      services.openssh = {
        enable = true;
        hostKeys = [
          {
            type = "ed25519";
            path = "/etc/ssh/ssh_host_ed25519_key";
          }
        ];
      };
      environment.etc."ssh/ssh_host_ed25519_key" = {
        source = keys.snakeOilEd25519PrivateKey;
        mode = "0600";
      };
      users.users.simon = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
      };
      nix.settings = {
        experimental-features = [ "nix-command" ];
        trusted-users = [ "@wheel" ];
        substituters = lib.mkForce [ ];
      };
      networking.firewall.allowedTCPPorts = [ 22 ];
      zramSwap.enable = true;
      virtualisation.memorySize = 1536;
      # React within seconds in the test; production keeps systemd's 30 s
      # and the NixOS module's 80% limit.
      systemd.oomd.settings.OOM.DefaultMemoryPressureDurationSec = "5s";
      systemd.slices.system.sliceConfig.ManagedOOMMemoryPressureLimit = lib.mkForce "20%";
    };
  # A derivation nobody has built: its output exists only where it ran.
  job =
    name:
    pkgs.writeShellScript "job-${name}" ''
      nix-build --no-out-link -E 'derivation { name = "${name}"; system = builtins.currentSystem; builder = "/bin/sh"; args = [ "-c" "echo ${name} > $out" ]; }' 2>&1
    '';
  ssh = "ssh -i /root/k -o StrictHostKeyChecking=no -o ConnectTimeout=10";
in
pkgs.testers.runNixOSTest {
  name = "build-federation";
  nodes.fast = common;
  nodes.laptop = common;
  nodes.client =
    { lib, ... }:
    {
      imports = [ common ];
      nix.settings.max-jobs = lib.mkForce 0;
    };

  testScript = ''
    import datetime
    start_all()
    for m in (fast, laptop, client):
        m.wait_for_unit("sshd.service")
        m.wait_for_unit("nix-daemon.socket")

    with subtest("memory guard settings are live"):
        assert fast.succeed("systemctl show sshd -p MemoryMin --value").strip() == "67108864"
        assert fast.succeed("systemctl show system.slice -p MemoryMin --value").strip() == "536870912"
        fast.succeed("systemctl show nix-daemon -p Environment --value | grep -q TMPDIR=/nix/var/nix/builds")
        fast.wait_until_succeeds("oomctl | grep -q /system.slice")

    with subtest("a fleet key may only run the gate"):
        client.succeed("cp /etc/ssh/ssh_host_ed25519_key /root/k && chmod 600 /root/k")
        out = client.succeed("timeout 20 ${ssh} simon@fast id </dev/null 2>&1 || true")
        assert "uid=" not in out, out

    with subtest("the laptop refuses and Nix uses the next builder"):
        reason = laptop.succeed("su simon -c 'nix-builder-gate status'")
        assert "refusing" in reason, reason
        out = client.succeed("${job "first"}")
        assert "nix-builder-laptop" in out and "cannot build on" in out, out
        path = out.strip().splitlines()[-1]
        fast.succeed(f"test -e {path}")
        laptop.fail(f"test -e {path}")

    with subtest("a manual choice makes the preferred laptop accept"):
        laptop.succeed("su simon -c 'nix-builder-gate set on' | grep -q choice-on")
        out = client.succeed("${job "second"}")
        path = out.strip().splitlines()[-1]
        laptop.succeed(f"test -e {path}")
        fast.fail(f"test -e {path}")

    with subtest("oomd ends a cgroup under sustained pressure while SSH answers"):
        fast.succeed(
            "systemd-run --unit=hog -p MemoryHigh=64M "
            "${pkgs.stress-ng}/bin/stress-ng --vm 2 --vm-bytes 400M --vm-keep --timeout 300"
        )
        fast.wait_until_succeeds("journalctl -u systemd-oomd | grep -q hog.service", timeout=datetime.timedelta(seconds=180))
        fast.wait_until_fails("systemctl is-active hog", timeout=datetime.timedelta(seconds=30))
        # The login reaches the gate, which starts the daemon; with no input
        # the daemon reports end-of-file. That proves sshd and the gate answered.
        out = client.succeed("timeout 20 ${ssh} simon@fast </dev/null 2>&1 || true")
        assert "end-of-file" in out, out
  '';
}
