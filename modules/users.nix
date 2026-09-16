# The one human user, and the hjem wiring that manages their $HOME.
#
# hjem is a NixOS module, so there is no second module system here. Files in
# $HOME are declared in the same evaluation as the rest of the machine.
{ config, inputs, ... }:
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
      openssh.authorizedKeys.keys = [ config.cairn.sshKey ];

      # Bootstrap only. Without a password NixOS creates a locked account,
      # which means no console login, which on a wifi-only laptop means no
      # way to reach a network and therefore no way to SSH in at all.
      #
      # hashedPassword, not initialPassword: initialPassword applies only when
      # the account is first created, and these accounts already exist on the
      # stick. hashedPassword is re-applied on every activation, so it repairs
      # an account that was created locked.
      #
      # This hash is yescrypt of "cairn" and it sits in the world-readable Nix
      # store. It is a bootstrap credential, not a secret. Replace it with a
      # sops-nix backed hashedPasswordFile once the machine can fetch secrets.
      hashedPassword = "$y$j9T$O5HJmtS8uIVq0xLPJqrTh1$cr61VV5WOS1Ex5dQ7Wlw47/xUYN1h8.9SIP0viOZUR5";
    };

    # Remote deploys land as root over SSH, so root needs the same key.
    users.users.root = {
      openssh.authorizedKeys.keys = [ config.cairn.sshKey ];
      # Escape hatch if the graphical login breaks. Same caveats as above.
      hashedPassword = "$y$j9T$O5HJmtS8uIVq0xLPJqrTh1$cr61VV5WOS1Ex5dQ7Wlw47/xUYN1h8.9SIP0viOZUR5";
    };

    hjem = {
      clobberByDefault = true;
      users.simon.directory = "/home/simon";
    };
  };
}
