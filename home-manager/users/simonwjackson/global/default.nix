{ inputs
, outputs
, lib
, config
, pkgs
, ...
}: {
  imports = [
    inputs.nix-colors.homeManagerModules.default
    inputs.agenix.homeManagerModules.age
    ./git.nix
    ./shell-gpt.nix
    ./eza.nix
    ./lf
    ./neovim
    ./tmux
    ./zsh
  ] ++ (builtins.attrValues outputs.homeManagerModules);

  # TODO: Set your username from $mainUser
  home = {
    username = "simonwjackson";
    homeDirectory = "/home/simonwjackson";
    packages = [
      pkgs.killall
      pkgs.jq
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
    };
  };

  programs.mcfly = {
    enable = true;
    enableZshIntegration = config.programs.zsh.enable;
    enableBashIntegration = config.programs.bash.enable;
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
        } + "/Dracula.tmTheme");
    };

    config = {
      theme = "Dracula";
      italic-text = "always";
    };
  };

  xdg.desktopEntries = {
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

  programs.taskwarrior.enable = true;
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

  # programs.xpo = {
  #   enable = true;
  #   defaultServer = "unzen";
  # };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";
}
