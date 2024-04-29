{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # An instance of `pkgs` with your overlays and packages applied is also available.
  pkgs,
  # You also have access to your flake's inputs.
  inputs,
  # Additional metadata is provided by Snowfall Lib.
  home, # The home architecture for this host (eg. `x86_64-linux`).
  target, # The Snowfall Lib target for this home (eg. `x86_64-home`).
  format, # A normalized name for the home target (eg. `home`).
  virtual, # A boolean to determine whether this home is a virtual target using nixos-generators.
  host, # The host name for this home.
  # All other arguments come from the home home.
  config,
  ...
}: {
  # imports =
  #   [
  #     inputs.agenix.homeManagerModules.age
  #   ]
  #   ++ (builtins.attrValues outputs.homeManagerModules);

  age.secrets.atuin_key.file = ../../secrets/atuin_key.age;
  age.secrets.atuin_session.file = ../../secrets/atuin_session.age;

  # TODO: Set your username from $mainUser
  home = {
    sessionVariables = {
      EDITOR = "${pkgs.neovim}";
    };
    packages = [
    ];
  };

  nixpkgs = {
    config = {
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
      permittedInsecurePackages = [
        # "nix-2.16.2"
      ];
    };
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

  programs.home-manager.enable = true;

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
    # compression = true;
    # controlMaster = "auto";
    # forwardAgent = true;
    matchBlocks = {
      # "*" = {
      #   sendEnv = ["TZ"];
      # };
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
}
