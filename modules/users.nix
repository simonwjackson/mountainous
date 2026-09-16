# The one human user, and the hjem wiring that manages their $HOME.
#
# hjem is a NixOS module, so there is no second module system here. Files in
# $HOME are declared in the same evaluation as the rest of the machine.
{ inputs, ... }:
{
  nixos.modules.base = {
    imports = [ inputs.hjem.nixosModules.default ];

    users.users.simon = {
      isNormalUser = true;
      description = "simon";
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
      ];
      openssh.authorizedKeys.keys = [
        # "ssh-ed25519 AAAA... simon"
      ];
    };

    hjem = {
      clobberByDefault = true;
      users.simon.directory = "/home/simon";
    };
  };
}
