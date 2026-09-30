# The Korri product on a mountainous host.
#
# Korri owns the whole product composition: korrid, the portal and its
# browser, the compositor, input, the plugin host, and the `korri` account.
# A host adds only its hardware facts under services.korriLinuxHost.
# This layer departs from Korri's device policy in two places only, both so
# mountainous can keep managing the machine: root's password and SSH.
#
# A host that takes this layer must also set
#   nixpkgs = inputs.korri.inputs.nixpkgs;
# Korri patches Sway for one exact upstream version, so its modules do not
# evaluate on our nixpkgs.
{ inputs, ... }:
{
  nixos.modules.korri =
    { lib, ... }:
    {
      imports = [ inputs.korri.nixosModules.korri-product ];

      # Korri devices ship with an empty root password. Here base.nix gives
      # root the fleet password file, which wins with immutable users anyway.
      # Clearing Korri's value states that and removes NixOS's warning about
      # two password options.
      users.users.root.initialHashedPassword = lib.mkForce null;

      # Korri devices turn network SSH off. Mountainous installs and updates
      # hosts over SSH as root, so without it this host could never be
      # changed again. Key-only access from base.nix still applies. Korri
      # also closes the port, and installs reach the host by its LAN address,
      # so the port opens too.
      services.openssh.enable = lib.mkForce true;
      services.openssh.openFirewall = lib.mkForce true;
    };
}
