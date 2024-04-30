{
  config,
  inputs,
  lib,
  options,
  pkgs,
  ...
}: {
  imports = [
    inputs.agenix.homeManagerModules.age
  ];

  config = {
    age = {
      identityPaths =
        options.age.identityPaths.default
        ++ [
          # TODO: Pull this value from somewhere else in the config
          "${config.home.homeDirectory}/.ssh/agenix"
        ];
    };
    age.secrets.atuin_key.file = ../../../secrets/atuin_key.age;
    age.secrets.atuin_session.file = ../../../secrets/atuin_session.age;

    home = {
      sessionVariables = {
        EDITOR = "nvim";
      };
      packages = [
      ];
    };

    # nixpkgs = {
    #   config = {
    #     allowUnfree = true;
    #     # Workaround for https://github.com/nix-community/home-manager/issues/2942
    #     allowUnfreePredicate = _: true;
    #     permittedInsecurePackages = [
    #       # "nix-2.16.2"
    #     ];
    #   };
    # };

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

    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
      enableZshIntegration = true;
      settings = {
        auto_sync = true;
        enter_accept = true;
        filter_mode_shell_up_key_binding = "workspace";
        inline_height = 10;
        key_path = config.age.secrets.atuin_key.path;
        search_mode = "fuzzy";
        secrets_filter = false;
        session_path = config.age.secrets.atuin_session.path;
        style = "compact";
        sync_address = "https://api.atuin.sh";
        sync_frequency = "5m";
      };
    };

    programs.ssh = {
      enable = true;
      compression = true;
      controlMaster = "auto";
      forwardAgent = true;
      matchBlocks = {
        "*" = {
          sendEnv = ["TZ"];
        };
        "ushiro,ushiro.hummingbird-lake.ts.net,ushiro.mountain.ous" = {
          user = "sjackson217";
        };
      };
    };

    # programs.xpo = {
    #   enable = true;
    #   defaultServer = "unzen";
    # };

    # Nicely reload system units when changing configs
    systemd.user.startServices = "sd-switch";
  };
}
