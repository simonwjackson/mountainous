{
  options,
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.mountainous.user;
  ifTheyExist = groups: builtins.filter (group: builtins.hasAttr group config.users.groups) groups;
in {
  options.mountainous.user = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "The name to use for the user account.";
    };

    fullName = lib.mkOption {
      type = lib.types.str;
      default = "Admin";
      description = "The full name of the user.";
    };

    email = lib.mkOption {
      type = lib.types.str;
      default = "admin@localhost";
      description = "The email of the user.";
    };

    extraGroups = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Groups for the user to be assigned.";
    };

    extraOptions = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Extra options passed to `users.users.<name>`.";
    };

    hashedPasswordFile = lib.mkOption {
      type = lib.types.path;
      default = null;
      description = "The path to a file containing the hashed password for the user.";
    };
  };

  config = {
    environment.systemPackages = with pkgs; [
    ];

    # programs.zsh = {
    #   histFile = "$XDG_CACHE_HOME/zsh.history";
    # };

    # mountainous.home = {
    #   extraOptions = {
    #     home.shellAliases = {
    #       lc = "${pkgs.colorls}/bin/colorls --sd";
    #       lcg = "lc --gs";
    #       lcl = "lc -1";
    #       lclg = "lc -1 --gs";
    #       lcu = "${pkgs.colorls}/bin/colorls -U";
    #       lclu = "${pkgs.colorls}/bin/colorls -U -1";
    #     };
    #
    #     programs = {
    #       starship = {
    #         enable = true;
    #         settings = {
    #           character = {
    #             success_symbol = "[➜](bold green)";
    #             error_symbol = "[✗](bold red) ";
    #             vicmd_symbol = "[](bold blue) ";
    #           };
    #         };
    #       };
    #
    #       zsh = {
    #         enable = true;
    #         enableCompletion = true;
    #         enableAutosuggestions = true;
    #         syntaxHighlighting.enable = true;
    #
    #         initExtra =
    #           ''
    #             # Fix an issue with tmux.
    #             export KEYTIMEOUT=1
    #
    #             # Use vim bindings.
    #             set -o vi
    #
    #             # Improved vim bindings.
    #             source ${pkgs.zsh-vi-mode}/share/zsh-vi-mode/zsh-vi-mode.plugin.zsh
    #           ''
    #           + optionallib.lib.types.string cfg.prompt-init ''
    #             ${pkgs.toilet}/bin/toilet -f future "Plus Ultra" --gay
    #           '';
    #
    #         shellAliases = {
    #           say = "${pkgs.toilet}/bin/toilet -f pagga";
    #         };
    #
    #         plugins = [
    #           {
    #             name = "zsh-nix-shell";
    #             file = "nix-shell.plugin.zsh";
    #             src = pkgs.fetchFromGitHub {
    #               owner = "chisui";
    #               repo = "zsh-nix-shell";
    #               rev = "v0.4.0";
    #               sha256 = "037wz9fqmx0ngcwl9az55fgkipb745rymznxnssr3rx9irb6apzg";
    #             };
    #           }
    #         ];
    #       };
    #     };
    #   };
    # };

    users.mutableUsers = false;
    users.users.${cfg.name} =
      {
        isNormalUser = true;

        openssh.authorizedKeys.keys = [
          (builtins.readFile ./id_rsa.pub)
          "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlS7mK1MSLJviO83iAxwE5FQOu6FU9IeY6qcj6qYZ1s8qevcgj94CKhLq/ud/TexZ3qWVHkidmX0idQ4eo10lCYhAMynxT4YbtXDvHzWeeAYVN9JGyBdl4+HNctzdIKDrdOZzu+MBKgXjshuSntMUIabe7Bes+5B75ppwWqANFNPMKUSqTENxvmZ6mHF+KdwOI1oXYvOHD5y3t1dtWWcLMrot6F/ZUae5L7sRp+PqykOV4snI06uTeUxs0cTZJULDwNgngqIG9qs72BCfVvuOOwYosezUoajikPzzbBOJBl6l3M7MSJQfilVgvT/gHAxJKuZ1RzrPrssYBCbVanEL6dXuhiI25yxQvIqxDJmLzI9hvVwGgJJzov9BduO+vvPX/AwMd1oLxScgISkK/y+6+VHz+ey88gVniw22mSG0ueG11eebtp9c/lmBpNxZ30gmaINbgxZn4sM99RtC3E8eJ+KmKet8L+tFtVdeCYB7pgk8k/h06s9s3r34TGJ+SmrU="
        ];

        packages = with pkgs; [
          mountainous.ex
        ];

        # TODO: Move out of this module
        hashedPasswordFile = cfg.hashedPasswordFile;
        home = "/home/${cfg.name}";
        group = "users";
        extraGroups =
          ifTheyExist [
            "audio"
            "deluge"
            "dialout"
            "disk"
            "docker"
            "git"
            "i2c"
            "libvirtd"
            "minecraft"
            "network"
            "networkmanager"
            "podman"
            "video"
            "wheel"
            "steamcmd"
          ]
          ++ cfg.extraGroups;

        shell = pkgs.zsh;

        # Arbitrary user ID to use for the user. Since I only
        # have a single user on my machines this won't ever collide.
        # However, if you add multiple users you'll need to change this
        # so each user has their own unique uid (or leave it out for the
        # system to select).
        uid = 1000;
      }
      // cfg.extraOptions;
  };
}
