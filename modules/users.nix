# The one human user, and the hjem wiring that manages their $HOME.
#
# hjem is a NixOS module, so there is no second module system here. Files in
# $HOME are declared in the same evaluation as the rest of the machine.
{ config, inputs, ... }:
# Two module systems meet in this file and both call their argument `config`.
#
#   flake  -- the flake-parts config, where mountainous.sshKey is declared
#             (modules/identity.nix, at the top level)
#   config -- the NixOS config, where sops.secrets lives
#
# Writing the layer as a plain attrset leaves only the flake-parts config in
# scope, and reaching for config.sops from there fails with the unhelpful
# "attribute 'sops' missing". Taking NixOS module arguments fixes that but
# shadows the outer name, so the outer one is captured here first.
let
  flake = config;
in
{
  nixos.modules.base =
    { config, ... }:
    {
      imports = [ inputs.hjem.nixosModules.default ];

      # The config owns the accounts, not the machine.
      #
      # This is not a style preference. update-users-groups.pl only applies a
      # password to an account that already exists when mutableUsers is false:
      #
      #   $sp_pwdp = $u->{hashedPassword}
      #     if defined $u->{hashedPassword} && !$spec->{mutableUsers}; # FIXME
      #
      # With mutableUsers = true, an account created locked stays locked for
      # ever, no matter what the config later says. That is how hiyori ended up
      # unloggable after its first install.
      #
      # The cost: `passwd` no longer sticks across a rebuild. Change the
      # password by replacing the hash in sops:
      #
      #   ./scripts/secrets secrets/fleet.yaml
      #   mkpasswd -m yescrypt        # to generate a new one
      users.mutableUsers = false;

      users.users.simon = {
        isNormalUser = true;
        description = "simon";
        extraGroups = [
          "wheel"
          "networkmanager"
          "video"
        ];
        openssh.authorizedKeys.keys = [ flake.mountainous.sshKey ];

        # A password is not optional here. Without one NixOS creates a locked
        # account, which means no console login, which on a wifi-only laptop
        # means no way to reach a network and therefore no way to SSH in.
        #
        # The hash used to sit inline, and so in the world-readable Nix store,
        # where anyone with store access could attack it offline at their
        # leisure. It now lives encrypted in secrets/fleet.yaml and lands in
        # /run/secrets-for-users, which is root-only and on a ramfs.
        #
        # hashedPasswordFile, not hashedPassword: the file is re-read on every
        # activation, so it repairs an account that was created locked rather
        # than only applying at creation time.
        hashedPasswordFile = config.sops.secrets.user-password.path;
      };

      # Remote deploys land as root over SSH, so root needs the same key.
      users.users.root = {
        openssh.authorizedKeys.keys = [ flake.mountainous.sshKey ];
        # Escape hatch if the graphical login breaks. Same file as the user:
        # one password for the machine, not two to keep in step.
        hashedPasswordFile = config.sops.secrets.user-password.path;
      };

      hjem = {
        clobberByDefault = true;
        users.simon.directory = "/home/simon";
      };
    };
}
