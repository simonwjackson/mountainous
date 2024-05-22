# This file (and the global directory) holds config that i use on all hosts
{
  system,
  options,
  lib,
  inputs,
  pkgs,
  config,
  ...
}: let
  inherit (lib) mkDefault;
  inherit (lib.mountainous) enabled disabled;
in {
  programs.icho = {
    enable = true;
    environment = {
      NOTES_DIR = "/glacier/snowscape/notes";
    };
    environmentFiles = [
      config.age.secrets."user-simonwjackson-anthropic".path
    ];
  };

  programs.zsh.enable = true;

  mountainous = {
    agenix = mkDefault enabled;
    boot = mkDefault enabled;
    hardware = {
      battery = mkDefault disabled;
      bluetooth = mkDefault disabled;
      cpu = mkDefault enabled;
      hybrid-sleep = mkDefault disabled;
      touchpad = mkDefault disabled;
    };
    networking = {
      core = mkDefault enabled;
      secure-shell = mkDefault enabled;
      tailscaled = mkDefault enabled;
      zerotierone = mkDefault enabled;
    };
    performance = mkDefault enabled;
    printing = mkDefault enabled;
    security = mkDefault enabled;
    sound = mkDefault enabled;
    syncthing = mkDefault enabled;
    user = {
      enable = mkDefault true;
      name = mkDefault "simonwjackson";
      hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
    };
  };

  environment.pathsToLink = ["/share/zsh"];

  # services.udisks2.enable = true;

  # TODO: Move to (desktop?) profile
  environment.variables.BROWSER = "firefox-esr";

  programs.tmesh = let
    systems = ../../../systems;
    architectures = builtins.attrNames (builtins.readDir systems);
    getHosts = arch:
      builtins.attrNames (builtins.readDir (systems + "/${arch}"));

    allHosts = lib.flatten (map (arch: getHosts arch) architectures);

    common = ''
      # allow passthrough of escape sequences
      set -g allow-passthrough on

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
      # set -s set-clipboard on

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
      hosts = allHosts;
      local-tmesh-server = {
        command = "nvim -c 'silent! autocmd TermClose * qa' -c 'terminal' -c 'startinsert'";
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

  # environment.enableAllTerminfo = true;

  hardware.enableRedistributableFirmware = mkDefault true;

  # $ nix search wget
  # TODO: dont hardcode system type
  environment.systemPackages = [
    inputs.agenix.packages."${system}".default
  ];

  # console = {
  #   font = lib.mkDefault "Lat2-Terminus16";
  #   keyMap = lib.mkDefault "us";
  # };

  services.gpm.enable = true; # TTY mouse
}
