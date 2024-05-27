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
  inherit (lib.snowfall.fs) get-file;
  inherit (lib) mkDefault;
  inherit (lib.mountainous) enabled disabled;
  inherit (lib.mountainous.syncthing) otherDevices;
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

  backpacker = {
    adb = {
      enable = mkDefault true;
      user = "simonwjackson";
    };
    agenix = {
      enable = true;
      secretsDir = get-file "secrets";
      user = "simonwjackson";
    };
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
      tailscaled = mkDefault enabled;
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
      workspace = {
        enable = mkDefault false;
        user = "simonwjackson";
      };
    };
    security = {
      enable = mkDefault true;
      user = "simonwjackson";
    };
    sound = mkDefault enabled;
    syncthing = {
      inherit otherDevices;
      enable = mkDefault true;
      systemsDir = get-file "systems";
      hostName = config.networking.hostName;
      user = "simonwjackson";
    };
    user = {
      enable = mkDefault true;
      name = mkDefault "simonwjackson";
      hashedPasswordFile = mkDefault config.age.secrets."user-simonwjackson".path;
      authorizedKeys = ["ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==" "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDlS7mK1MSLJviO83iAxwE5FQOu6FU9IeY6qcj6qYZ1s8qevcgj94CKhLq/ud/TexZ3qWVHkidmX0idQ4eo10lCYhAMynxT4YbtXDvHzWeeAYVN9JGyBdl4+HNctzdIKDrdOZzu+MBKgXjshuSntMUIabe7Bes+5B75ppwWqANFNPMKUSqTENxvmZ6mHF+KdwOI1oXYvOHD5y3t1dtWWcLMrot6F/ZUae5L7sRp+PqykOV4snI06uTeUxs0cTZJULDwNgngqIG9qs72BCfVvuOOwYosezUoajikPzzbBOJBl6l3M7MSJQfilVgvT/gHAxJKuZ1RzrPrssYBCbVanEL6dXuhiI25yxQvIqxDJmLzI9hvVwGgJJzov9BduO+vvPX/AwMd1oLxScgISkK/y+6+VHz+ey88gVniw22mSG0ueG11eebtp9c/lmBpNxZ30gmaINbgxZn4sM99RtC3E8eJ+KmKet8L+tFtVdeCYB7pgk8k/h06s9s3r34TGJ+SmrU="];
    };
    vpn-proxy = mkDefault disabled;
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
