{
  config,
  inputs,
  lib,
  pkgs,
  system,
  ...
}: let
  cfg = config.mountainous.gaming.steam;
  # steamAppsOverlay = "/home/${config.mountainous.user.name}/.var/app/com.valvesoftware.Steam/data/Steam/steamapps";
  # mountpoint = "${pkgs.util-linux}/bin/mountpoint";
  # mount = "${pkgs.mount}/bin/mount";
in {
  options.mountainous = {
    gaming.steam = {
      enable = lib.mkEnableOption "Enable steam";
      # steamApps = lib.mkOption {
      #   type = lib.types.path;
      #   description = "";
      # };
    };
  };

  config = lib.mkIf cfg.enable {
    mountainous.services.gamescope-reaper.enable = true;

    hardware = {
      steam-hardware.enable = true;
      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };

    programs = {
      steam = {
        enable = true;
        remotePlay.openFirewall = true;
        extest.enable = true;
        package = pkgs.steam.override {
          extraPkgs = pkgs:
            with pkgs; [
              # mangohud_git
              gamescope-wsi_git
              gamescope_git
            ];
        };
        extraCompatPackages = with pkgs; [
          proton-ge-custom
        ];
      };
    };

    # services.udev.extraRules = ''
    #   SUBSYSTEM=="misc", KERNEL=="uinput", OPTIONS+="static_node=uinput", TAG+="uaccess"
    # '';

    # systemd.services.mountSteamAppsOverlay = {
    #   # after = ["mountSnowscape.service"];
    #   script = ''
    #     install -d -o ${config.mountainous.user.name} -g users -m 770 ${cfg.steamApps}
    #     install -d -o ${config.mountainous.user.name} -g users -m 770 /home/${config.mountainous.user.name}/.var/app/com.valvesoftware.Steam/data/Steam/steamapps
    #     ${mountpoint} -q ${steamAppsOverlay} || ${mount} --bind ${cfg.steamApps} ${steamAppsOverlay}
    #   '';
    #   wantedBy = ["multi-user.target"];
    #   serviceConfig = {
    #     Type = "oneshot";
    #   };
    # };
  };
}
