{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.mountainous) enabled;
  inherit (lib) mkDefault;
in {
  imports = [
    inputs.agenix.homeManagerModules.age
  ];

  config = {
    mountainous = {
      agenix = mkDefault enabled;
      atuin = mkDefault enabled;
    };

    home = {
      sessionVariables = {
        EDITOR = "nvim";
      };
      packages = [
      ];
    };

    programs.bat = {
      enable = true;

      themes = {
        dracula = builtins.readFile (pkgs.fetchFromGitHub
          {
            owner = "dracula";
            repo = "sublime"; # Bat uses sublime syntax for its themes
            rev = "26c57ec282abcaa76e57e055f38432bd827ac34e";
            sha256 = "019hfl4zbn4vm4154hh3bwk6hm7bdxbr1hdww83nabxwjn99ndhv";
          }
          + "/Dracula.tmTheme");
      };

      config = {
        theme = "Dracula";
        italic-text = "always";
      };
    };

    programs.direnv = {
      enable = true;
      nix-direnv.enable = true;
      enableZshIntegration = config.programs.zsh.enable;
      enableBashIntegration = config.programs.bash.enable;
      # config = ''
      #   [whitelist]
      #   prefix = [ "/home/simonwjackson/code" ]
      # '';
    };

    programs.bash.enable = true;

    programs.ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      forwardAgent = true;
      matchBlocks = {
        "*" = {
          sendEnv = ["TZ"];
        };
        "ushiro,ushiro.hummingbird-lake.ts.net,ushiro.mountaino.us" = {
          user = "sjackson217";
        };
      };
    };

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";
  };
}
