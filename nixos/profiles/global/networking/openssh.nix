{
  outputs,
  lib,
  config,
  ...
}: let
  inherit (config.networking) hostName;
  hosts = outputs.nixosConfigurations;
  pubKey = host: builtins.readFile ../../../hosts/${host}/ssh_host_rsa_key.pub;
in {
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitUserEnvironment = "yes";
      # Harden
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      # Automatically remove stale sockets
      StreamLocalBindUnlink = "yes";
      # Allow forwarding ports to everywhere
      GatewayPorts = "clientspecified";
    };
  };

  programs.ssh = {
    # Each hosts public key
    knownHosts =
      builtins.mapAttrs
      (name: _: {
        publicKey = pubKey name;
        extraHostNames =
          (lib.optional (name == hostName) "localhost")
          ++ [
            "${name}.hummingbird-lake.ts.net"
            "${name}.mountain.ous"
          ];
      })
      hosts;
  };

  # Passwordless sudo when SSH'ing with keys
  security.pam.enableSSHAgentAuth = true;

  programs.mosh.enable = true;
}
