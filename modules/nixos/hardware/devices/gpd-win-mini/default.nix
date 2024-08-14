{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib) mkIf mkEnableOption;

  cfg = config.mountainous.hardware.devices.gpd-win-mini;
in {
  options.mountainous.hardware.devices.gpd-win-mini = {
    enable = mkEnableOption "Whether to enable GPD Win Mini adjustments";
  };

  config = mkIf cfg.enable {
    backpacker = {
      hardware = {
        bluetooth.enable = true;
        battery.enable = true;
        cpu.type = "amd";
      };
    };

    chaotic.mesa-git.enable = true;
    chaotic.mesa-git.fallbackSpecialisation = true;
    # chaotic.appmenu-gtk3-module.enable = true;
    chaotic.steam.extraCompatPackages = with pkgs; [
      proton-ge-custom
      gamescope
      mangohud
    ];

    boot.initrd.availableKernelModules = ["nvme" "xhci_pci" "thunderbolt" "usbhid" "usb_storage" "uas" "sd_mod"];
    boot.kernelPackages = pkgs.linuxPackages_zen;

    # hardware.gpd-fan.enable = true;

    # *might* fix white/flashing screens
    # kernelParams = ["amdgpu.sg_display=0"];
    # WARN: promises better energy efficency but This *might* cause lower fps. kernel 6.3 or higher
    # kernelParams = [ "amd_pstate=active" ];
    boot.kernelParams = [
      "fbcon=rotate:1"
      "video=eDP-1:panel_orientation=right_side_up"
      "amd_pstate=active"
    ];

    # Required for grub to properly display the boot menu.
    boot.loader.grub.gfxmodeEfi = lib.mkDefault "1080x1920x32";

    # INFO: Jovian NixOS steam module
    # https://github.com/Jovian-Experiments/Jovian-NixOS/blob/development/modules/steam/steam.nix

    hardware = {
      i2c.enable = true;
      sensor.iio.enable = true;
      graphics = {
        enable32Bit = true;
        extraPackages = with pkgs; [
          rocm-opencl-icd
          vaapiVdpau
          rocm-opencl-runtime
          libvdpau-va-gl
        ];
      };
      enableAllFirmware = true;
      cpu.amd = {
        updateMicrocode = true;
        ryzen-smu.enable = true;
      };
      steam-hardware.enable = true;
    };
    nixpkgs = {
      config = {
        steam = pkgs.steam.override {
          extraPkgs = pkgs:
            with pkgs; [
              gamescope-wsi_git
              gamescope_git
              # stable.gamescope
              xorg.libXcursor
              xorg.libXi
              xorg.libXinerama
              xorg.libXScrnSaver
              libpng
              libpulseaudio
              libvorbis
              stdenv.cc.cc.lib
              libkrb5
              keyutils
              mangohud
            ];
        };
        allowUnfree = true;
        permittedInsecurePackages = ["python-2.7.18.6"];
      };
    };
    programs = {
      #gamescope.package = pkgs.stable.gamescope;
      gamemode.enable = true;
      xwayland.enable = true;
      steam = {
        # gamescopeSession = {
        #   enable = true;
        #   args = ["--rt" "-H 1600" "-h 720" "-b" "-f" "-F fsr"];
        #   env = {ENABLE_GAMESCOPE_WSI = "1";};
        #   #steamArgs = [ "-pipewire-dmabuf" ];
        # };
        enable = true;
        remotePlay.openFirewall = true;
      };
      gamescope = {
        enable = true;
        # args = ["--rt" "-H 1080" "-h 720" "-f" "-F fsr"];
      };
    };
  };
}
