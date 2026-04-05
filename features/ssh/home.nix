{lib, ...}: let
  knownHosts = import ./hosts.nix;

  defaultUser = "simonwjackson";
  defaultPort = 22;

  hostBlocks =
    lib.mapAttrs (name: meta: {
      user = meta.user or defaultUser;
      port = meta.port or defaultPort;
    })
    knownHosts;
in {
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    extraConfig = lib.mkDefault ''
      IgnoreUnknown WarnWeakCrypto
      WarnWeakCrypto no
    '';
    matchBlocks =
      hostBlocks
      // {
        "*" = {
          user = defaultUser;
          forwardAgent = false;
          addKeysToAgent = "no";
          compression = false;
          serverAliveInterval = 0;
          serverAliveCountMax = 3;
          hashKnownHosts = false;
          userKnownHostsFile = "~/.ssh/known_hosts";
          controlMaster = "no";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "no";
        };
      };
  };
}
