# This file (and the global directory) holds config that i use on all hosts
{
  config,
  host,
  inputs,
  lib,
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

  programs.zsh.enable = true;
  services.metered-connection.networks = lib.mkAfter [
    "usu"
  ];

  mountainous.services.nfs-auto-shares = {
    enable = true;
    hosts = {
      cho = {
        hostname = "cho";
        shareName = "snowscape";
      };
      aka = {
        hostname = "aka";
        shareName = "snowscape";
      };
      fuji = {
        hostname = "fuji";
        shareName = "snowscape";
      };
      hira = {
        hostname = "hira";
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
    adb = mkDefault disabled;
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
        enable = false;
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
    syncthing = {
      inherit otherDevices;

      enable = mkDefault true;

      cert =
        mkIf (config.mountainous.syncthing.enable && builtins.hasAttr "${host}-syncthing-cert" config.age.secrets)
        (mkDefault config.age.secrets."${host}-syncthing-cert".path);
      key =
        mkIf (config.mountainous.syncthing.enable && builtins.hasAttr "${host}-syncthing-key" config.age.secrets)
        (mkDefault config.age.secrets."${host}-syncthing-key".path);

      hostName = host;
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
      TODO: Move them back
    '';
  in {
    enable = true;
    tmeshServerTmuxConfig = common;
    tmeshTmuxConfig = ''
      TODO: Move them back

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

  environment.systemPackages = [
    inputs.nixos-anywhere.packages.${system}.nixos-anywhere
  ];

  time.timeZone = "America/Chicago";
  hardware = {
    enableRedistributableFirmware = mkDefault true;
    enableAllFirmware = true;
  };

  home-manager.backupFileExtension = "bak";

  services.gpm.enable = true; # TTY mouse
}
