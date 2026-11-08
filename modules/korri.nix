# The Korri product on a mountainous host.
#
# Korri owns the whole product composition: korrid, the native shell, the
# compositor, input, the plugin host, and the `korri` account.
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
    { config, lib, pkgs, ... }:
    let
      runtimeUid = toString config.services.korriProduct.runtimeAccount.uid;
    in
    {
      imports = [ inputs.korri.nixosModules.korri-product ];

      # The published @korri:sunshine runtime.sh hard-codes /run/user/1000,
      # Korri's default runtime UID. Here simon holds 1000 and the korri
      # account has another UID, so Sunshine never finds the compositor.
      # Show the korri account's runtime directory at that path, inside the
      # Sunshine unit only. Remove this when the plugin reads its own UID.
      systemd.packages = lib.mkIf (runtimeUid != "1000") [
        (pkgs.writeTextDir "lib/systemd/system/korri-sunshine.service.d/runtime-dir.conf" ''
          [Service]
          BindPaths=/run/user/${runtimeUid}:/run/user/1000
        '')
      ];

      # The Sunshine plugin's setup unit creates this group with groupadd
      # (GID 980, plugins/sunshine/input-seat-setup.sh). Users here are
      # immutable, so each NixOS switch deleted it and Sunshine then failed
      # at Group=. Declaring it keeps it across switches.
      users.groups.korri-sunshine-input-seat.gid = 980;

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

      # Korri images set the official plugin catalog in their image module,
      # which a mountainous host does not import. Use the same pinned catalog
      # (korri nix/product/published-plugins.nix) so korri-plugin can install
      # @korri plugins such as Gamescope and Sunshine.
      services.korri.pluginHost.officialCatalogUrl =
        (import "${inputs.korri}/nix/product/published-plugins.nix").catalogUrl;
    };
}
