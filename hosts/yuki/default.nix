{ config, lib, pkgs, nixos-hardware, ... }:

let
  passwordSecretFile = ../../secrets/hosts/yuki/simonwjackson-password-hash.age;
  hasPasswordSecret = builtins.pathExists passwordSecretFile;
in
{
  imports = [
    ./hardware.nix
    ./disko.nix
    # TODO: nixos-hardware has no exact Lenovo Yoga Book 9i Gen 10 (83Q8) profile yet;
    # use the nearest available Lenovo IdeaPad 14-inch Intel module for now.
    nixos-hardware.nixosModules.lenovo-ideapad-14imh9
  ];

  home-manager.users.simonwjackson = import ../../home/simonwjackson;

  networking.hostName = "yuki";
  networking.useDHCP = lib.mkDefault true;
  time.timeZone = "America/Denver";
  i18n.defaultLocale = "en_US.UTF-8";

  age.secrets.simonwjackson-password-hash = lib.mkIf hasPasswordSecret {
    file = passwordSecretFile;
    owner = "root";
    group = "root";
    mode = "0400";
  };

  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" ];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ=="
    ];
  } // lib.optionalAttrs hasPasswordSecret {
    hashedPasswordFile = config.age.secrets.simonwjackson-password-hash.path;
  };

  boot = {
    # Arrow Lake-H suspend-to-idle support requires Linux 6.15 or newer.
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "i915.enable_psr=0"
      ''acpi_osi="!Windows 2020"''
      "mem_sleep_default=s2idle"
    ];
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 20480;
    }
  ];

  systemd.sleep.extraConfig = ''
    HibernateDelaySec=15min
  '';

  services.logind.settings.Login = {
    HandleLidSwitch = "suspend-then-hibernate";
    HandleLidSwitchExternalPower = "suspend-then-hibernate";
    HandlePowerKey = "hibernate";
    HandleSuspendKey = "suspend-then-hibernate";
    HandleHibernateKey = "hibernate";
  };

  # Keep Hyprland wiring local here instead of importing nix/features/hyprland/nixos.nix:
  # that module assumes a separate hyprland flake input and configures SDDM/autologin,
  # while yuki should use greetd + tuigreet.
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    config.common.default = "*";
  };

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
      user = "greeter";
    };
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "modesetting" ];

  services.pulseaudio.enable = false;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  security.rtkit.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkForce false;

  systemd.services.disable-elan-wakeup-before-sleep = {
    description = "Disable ELAN touchpad wakeup sources before sleep";
    before = [ "sleep.target" ];
    wantedBy = [ "sleep.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      # Lenovo dual-screen systems may wake immediately if ELAN wakeup stays enabled.
      # Prefer the generic detection pattern first; replace with a fixed sysfs path if one
      # proves stable on this machine after first boot.
      while IFS= read -r wakeup; do
        echo disabled > "$wakeup" || true
      done < <(find /sys -name "wakeup" | xargs grep -l "enabled" 2>/dev/null | grep -i elan || true)
    '';
  };

  system.stateVersion = "24.11";
}
