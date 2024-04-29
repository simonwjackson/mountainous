{
  lib,
  config,
  system,
  ...
}: let
  inherit (config.networking) hostName;
  # pubKey = host: builtins.readFile ../../../../systems/${system}/${config.networking.hostName}/ssh_host_rsa_key.pub;
in {
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      # PermitUserEnvironment = "yes";
      # Harden
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Automatically remove stale sockets
      # StreamLocalBindUnlink = "yes";
      # Allow forwarding ports to everywhere
      # GatewayPorts = "clientspecified";
      X11Forwarding = true;
      X11DisplayOffset = 10;
      X11UseLocalhost = true;
    };
  };

  # FIX: Get list of managed hosts
  # programs.ssh = {
  #   # Each hosts public key
  #   knownHosts =
  #     builtins.mapAttrs
  #     (name: _: {
  #       publicKey = pubKey name;
  #       extraHostNames =
  #         (lib.optional (name == hostName) "localhost")
  #         ++ [
  #           "${name}.hummingbird-lake.ts.net"
  #           # TODO: Grab this from somwhere else in to config
  #           "${name}.mountaino.us"
  #         ];
  #     })
  #     allManagedHosts;
  # };

  # Passwordless sudo when SSH'ing with keys
  security.pam.sshAgentAuth.enable = true;
  programs.mosh.enable = true;
}
