# Boot the actual host hooks, then attack the read-only file's user-owned lock.
{
  pkgs,
  inputs,
  profile,
  agent,
  verifyBootOrder,
}:
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
    machine.succeed("su -s /bin/sh simon -c '${pkgs.python3}/bin/python3 ${agent.cliPolicyGuard}/cli-policy.py ${agent}/bin/pi /var/lib/pi/simon/agent/settings.json --agent-dir /var/lib/pi/simon/agent'")
    machine.succeed("test -d /var/lib/pi/simon/agent/settings.json.lock")
  '';
}
