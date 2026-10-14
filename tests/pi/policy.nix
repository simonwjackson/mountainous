# Boot the actual host hooks, then attack the read-only file's user-owned lock.
{
  pkgs,
  inputs,
  profile,
  agent,
  runtime,
  verifyBootOrder,
}:
let
  manager = "${agent}/lib/node_modules/@earendil-works/pi-coding-agent/dist/core/settings-manager.js";
in
pkgs.testers.runNixOSTest {
  name = "pi-readonly-policy";
  nodes.machine =
    { lib, ... }:
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
        profile.hostModule
      ];
      options.mountainous.appProfiles.pi.enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      # This offline VM tests settings, not production secret decryption.
      config = {
        sops.secrets = lib.mkForce { };
        users.users.simon = {
          isNormalUser = true;
        };
        virtualisation.memorySize = 2048;
      };
    };
  testScript = ''
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("var-lib-pi-simon-agent-settings.json.mount")
    machine.succeed("${verifyBootOrder}")
    machine.succeed("findmnt -rn --mountpoint /var/lib/pi/simon/agent/settings.json -o VFS-OPTIONS | grep -w ro")
    machine.fail("su -s /bin/sh simon -c 'echo changed >> /var/lib/pi/simon/agent/settings.json'")
    machine.succeed("su -s /bin/sh simon -c '${runtime}/bin/bun ${./settings-policy.mjs} ${manager} /var/lib/pi/simon/agent /var/lib/pi/simon/agent/settings.json'")
    machine.succeed("test -d /var/lib/pi/simon/agent/settings.json.lock")
    # The actual CLI must terminate on invalid or missing global policy.
    machine.succeed("mkdir -p /tmp/pi-broken; echo invalid > /tmp/pi-broken/settings.json")
    status, _ = machine.execute("PI_OFFLINE=1 PI_CODING_AGENT_DIR=/tmp/pi-broken ${pkgs.coreutils}/bin/timeout 10 ${agent}/bin/pi --version > /tmp/pi-invalid.log 2>&1")
    machine.log(machine.succeed("cat /tmp/pi-invalid.log"))
    assert status == 1, status
    machine.succeed("grep -E 'SyntaxError|JSON' /tmp/pi-invalid.log")
    machine.succeed("rm /tmp/pi-broken/settings.json")
    status, _ = machine.execute("PI_OFFLINE=1 PI_CODING_AGENT_DIR=/tmp/pi-broken ${pkgs.coreutils}/bin/timeout 10 ${agent}/bin/pi --version > /tmp/pi-missing.log 2>&1")
    assert status == 1, status
    machine.succeed("grep ENOENT /tmp/pi-missing.log")
  '';
}
