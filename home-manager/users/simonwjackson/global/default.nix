{
  inputs,
  outputs,
  lib,
  config,
  pkgs,
  age,
  rootPath,
  ...
}: {
  imports =
    [
      inputs.nix-colors.homeManagerModules.default
      inputs.agenix.homeManagerModules.age
      ./git.nix
      ./shell-gpt.nix
      ./eza.nix
      ./lf
      ./neovim
      ./tmux
      ./taskwarrior.nix
      ./zsh
    ]
    ++ (builtins.attrValues outputs.homeManagerModules);

  age.secrets.atuin_key.file = rootPath + /secrets/atuin_key.age;
  age.secrets.atuin_session.file = rootPath + /secrets/atuin_session.age;

  # TODO: Set your username from $mainUser
  home = {
    username = "simonwjackson";
    homeDirectory = "/home/simonwjackson";
    packages = [
      pkgs.killall
      pkgs.jq
      # inputs.cuttlefish.packages."x86_64-linux"."cuttlefi.sh"
      # pkgs.ex
    ];
  };

  nixpkgs = {
    # You can add overlays here
    overlays = [
      outputs.overlays.additions
      outputs.overlays.modifications
    ];
    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = _: true;
      permittedInsecurePackages = [
        "nix-2.16.2"
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

  xdg.desktopEntries = {
    lf = {
      type = "Application";
      name = "lf";
      comment = "Launches the lf file manager";
      icon = "utilities-terminal";
      terminal = false;
      exec = "kitty --  lf";
      # categories = "ConsoleOnly;System;FileTools;FileManager";
      # mimeType = "inode/directory";
      # keywords = "File;Manager;Browser;Explorer;Launcher;Vi;Vim;Python";
    };
    # obsidian = {
    #   name = "Obsidian";
    #   genericName = "Link Your Thinking";
    #   exec = "nix run --impure \"nixpkgs#obsidian\"";
    #   terminal = true;
    # };

    # vscode = {
    #   name = "VS Code";
    #   genericName = "VS Code";
    #   exec = "nix run --impure nixpkgs\#vscode";
    #   terminal = false;
    # };
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
  programs.nest-tmux = {
    enable = true;
    servers = [
      "unzen"
      "fiji"
      "zao"
    ];
  };

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
