# This file (and the global directory) holds config that i use on all hosts
{
  config,
  host,
  inputs,
  lib,
  options,
  pkgs,
  system,
  ...
}: let
  inherit (lib.snowfall.fs) get-file;
  inherit (lib) mkIf mkDefault;
  inherit (lib.mountainous) enabled disabled;
  inherit (lib.mountainous.util) allHosts;
  inherit (lib.mountainous.syncthing) otherDevices;
in {
  users = {
    groups.media = {
      gid = lib.mkForce 333;
    };

    users.media = {
      homeMode = "770";
      group = "media";
      uid = lib.mkForce 333;
      isNormalUser = false;
    };
  };

  programs.icho = {
    enable = lib.mkDefault true;
    environment = {
      NOTES_DIR = mkDefault "/snowscape/notes";
    };
    environmentFiles = [
      config.age.secrets."user-simonwjackson-anthropic".path
      config.age.secrets."deepseek-api-key".path
    ];
  };

  programs.zsh.enable = true;
  services.metered-connection.networks = lib.mkAfter [
    "usu"
  ];

  services.nfsAutofsModule = {
    enable = true;
    hosts = {
      aka = {
        hostname = "aka";
        shareName = "snowscape";
      };
      fiji = {
        hostname = "fiji";
        shareName = "snowscape";
      };
      kita = {
        hostname = "kita";
        shareName = "snowscape";
      };
      unzen = {
        hostname = "unzen";
        shareName = "snowscape";
      };
      zao = {
        hostname = "zao";
        shareName = "snowscape";
      };
    };
    ipRanges = [
      "192.18.1.0/24" # Home
      "100.64.0.0/10" # Tailscale
      "172.16.0.0/12" # Zerotierone
    ];
  };

  services.sunshine = {
    openFirewall = lib.mkDefault true;
    capSysAdmin = lib.mkDefault true;
    settings = {
      log_path = lib.mkDefault "/tmp/sunshine.log";
      key_rightalt_to_key_win = lib.mkDefault "enabled";
    };
    autoStart = lib.mkDefault false;
  };

  services.udev.extraRules = ''
    KERNEL=="uinput", GROUP="input", MODE="0660", OPTIONS+="static_node=uinput"
    KERNEL=="uinput", SUBSYSTEM=="misc", OPTIONS+="static_node=uinput", TAG+="uaccess"
  '';

  mountainous = {
    adb = mkDefault enabled;
    agenix = {
      enable = true;
      secretsDir = "${inputs.secrets}/agenix";
    };
    boot = mkDefault enabled;
    desktops = {
      hyprland = mkDefault disabled;
    };
    hardware = {
      battery = mkDefault disabled;
      bluetooth = mkDefault disabled;
      # cpu = mkDefault enabled;
      hybrid-sleep = mkDefault disabled;
      touchpad = mkDefault disabled;
    };
    networking = {
      core = mkDefault enabled;
      tailscaled = {
        enable = true;
        authKeyFile = config.age.secrets."tailscale".path;
      };
      zerotierone = mkDefault enabled;
      secure-shell = {
        enable = true;
        systemsDir = get-file "systems";
      };
    };
    performance = mkDefault enabled;
    printing = mkDefault enabled;
    profiles = {
      laptop = mkDefault disabled;
      workspace = mkDefault disabled;
    };
    security = mkDefault enabled;
    syncthing = rec {
      inherit otherDevices;

      cert = mkIf config.mountainous.syncthing.enable (mkDefault config.age.secrets."${host}-syncthing-cert".path);
      enable = mkDefault true;
      hostName = host;
      key = mkIf config.mountainous.syncthing.enable (mkDefault config.age.secrets."${host}-syncthing-key".path);
      systemsDir = get-file "systems";
    };
    sound = mkDefault enabled;
    user = {
      enable = mkDefault true;
      name = mkDefault "simonwjackson";
      hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
      authorizedKeys = let
        keysDir = "${inputs.secrets}/keys/users";
        isPublicKey = name: type: type == "regular" && lib.hasSuffix ".pub" name;
        pubKeyFiles = lib.filterAttrs isPublicKey (builtins.readDir keysDir);
        keys = lib.mapAttrsToList (name: _: builtins.readFile (keysDir + "/${name}")) pubKeyFiles;
      in
        keys;
    };
    vpn-proxy = mkDefault disabled;
  };

  environment.pathsToLink = ["/share/zsh"];

  # TODO: Move to (desktop?) profile
  environment.variables.BROWSER = "firefox";

  programs.tmesh = let
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
    tmeshServerTmuxConfig = common;
    tmeshTmuxConfig = ''
      # INFO: https://github.com/tmux/tmux/wiki/Clipboard#terminal-support---tmux-inside-tmux
      set -s set-clipboard on

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
              root = "/snowscape/code";
            }
          ];
        };
      };
    };
  };

  # environment.enableAllTerminfo = true;

  hardware.enableRedistributableFirmware = mkDefault true;

  # console = {
  #   font = lib.mkDefault "Lat2-Terminus16";
  #   keyMap = lib.mkDefault "us";
  # };

  services.gpm.enable = true; # TTY mouse
}
