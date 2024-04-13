# This file (and the global directory) holds config that i use on all hosts
{
  lib,
  inputs,
  outputs,
  pkgs,
  config,
  ...
}: {
  imports =
    [
      inputs.home-manager.nixosModules.home-manager
      ./networking
      ./nix.nix
      ./locale.nix
      ./printing.nix
      ./syncthing.nix
    ]
    ++ (builtins.attrValues outputs.nixosModules);

  home-manager.extraSpecialArgs = {inherit inputs outputs;};

  services.udisks2.enable = true;

  # TODO: Move to (desktop?) profile
  environment.variables.BROWSER = "firefox";

  services.tmesh = let
    common = ''
      set -g status off

      # Switch to another session if last window closed
      set-option -g detach-on-destroy off

      # Auto resize to the smallest screen connected
      set-option -g window-size smallest

      # Disable right click menu
      unbind-key -T root MouseDown3Pane

      # Respond to focus events
      set-option -g focus-events on

      # address vim mode switching delay (http://superuser.com/a/252717/65504)
      set-option -s escape-time 0

      # silent
      set-option -g visual-activity off
      set-option -g visual-bell off
      set-option -g visual-silence off
      set-option -g bell-action none

      # Ignore window notifications
      set-window-option -g monitor-activity off

    '';
  in {
    enable = true;
    tmeshServerTmuxConfig = ''
      # INFO: https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
      set -s set-clipboard on

      # set -as terminal-features ',tmux-256color:clipboard'

      ${common}
    '';
    tmeshTmuxConfig = ''
      # INFO: https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
      set -s set-clipboard on
      # #set -as terminal-features ',xterm-kitty:clipboard'

      # tmesh uses c-a
      set -g prefix C-a
      unbind-key C-b
      bind-key C-a send-prefix

      ${common}
    '';
    settings = {
      hosts = ["unzen" "zao" "fiji" "kita" "yari"];
      local-tmesh-server = {
        command = "${lib.meta.getExe pkgs.neovim} -c 'silent! autocmd TermClose * qa' -c 'terminal' -c 'startinsert'";
        plugins = {
          apps = ["btop"];
          projects = [
            {
              identifier = ".bare$|^.git$";
              root = "/glacier/snowscape/code";
            }
          ];
        };
      };
    };
  };

  nixpkgs = {
    overlays = [
      # Add overlays your own flake exports (from overlays and pkgs dir):
      outputs.overlays.additions
      outputs.overlays.modifications

      # You can also add overlays exported from other flakes:
      # inputs.neovim-nightly-overlay.overlays.default

      # Or define it inline, for example:
      # (final: prev: {
      #   hi = final.hello.overrideAttrs (oldAttrs: {
      #     patches = [ ./change-hello-to-hi.patch ];
      #   });
      # })
    ];
    config = {
      allowUnfree = true;
    };
  };

  # environment.enableAllTerminfo = true;

  hardware.enableRedistributableFirmware = true;
  networking.domain = "mountain.ous";

  # $ nix search wget
  # TODO: dont hardcode system type
  environment.systemPackages = [
    inputs.agenix.packages."x86_64-linux".default
  ];

  # Increase open file limit for sudoers
  security.pam.loginLimits = [
    {
      domain = "@wheel";
      item = "nofile";
      type = "soft";
      value = "524288";
    }
    {
      domain = "@wheel";
      item = "nofile";
      type = "hard";
      value = "1048576";
    }
  ];

  console = {
    font = lib.mkDefault "Lat2-Terminus16";
    keyMap = lib.mkDefault "us";
  };

  services.gpm.enable = true; # TTY mouse
}
