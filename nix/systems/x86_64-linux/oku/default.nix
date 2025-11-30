# Huawei MateBook E (DRC-W56) - "oku"
#
# KNOWN ISSUE: Suspend (s2idle/deep) does not work on this device.
# The DSI panel fails to reinitialize after resume due to i915 driver timing bugs.
#
# Symptoms after suspend:
#   - System wakes (network responds to ping)
#   - Screen remains black
#   - dmesg shows: "mismatch in pixel_rate (expected 291594, found 332418)"
#   - dmesg shows: "flip_done timed out" errors
#
# Root cause: The dual-link DSI panel comes back with different timing
# parameters than expected, causing the i915 driver to fail display flips.
#
# Related kernel bugs (as of 2025-11, all appear UNFIXED):
#   - https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/8992 (MateBook E DSI)
#   - https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/6607 (DSI burst mode mismatch)
#   - https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/6131 (DSI resume failure)
#
# Workaround: Use hibernate instead of suspend. Hibernate works perfectly.
# Periodically test newer kernels (6.14+) to check if the bug is fixed.
#
{
  config,
  pkgs,
  lib,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
  ];

  boot = {
    # Kernel 6.12 - newest working kernel for MateBook E DSI panel
    # Kernel 6.13+ has i915 DSI divide-by-zero bug on boot
    # See: https://gitlab.freedesktop.org/drm/i915/kernel/-/issues/8992
    kernelPackages = pkgs.linuxPackages_6_12;

    initrd = {
      availableKernelModules = [
        "xhci_pci"
        "thunderbolt"
        "nvme"
        "uas"
        "usbhid"
        "sd_mod"
      ];
      kernelModules = ["i915"]; # Early KMS for Intel graphics
    };

    kernelModules = [
      "kvm-intel"
      "i915"
      "btusb"
      "hid_multitouch"
      # IIO sensors for rotation
      "hid_sensor_rotation"
      "hid_sensor_accel_3d"
      "hid_sensor_gyro_3d"
      "hid_sensor_als"
    ];

    extraModulePackages = [];

    kernelParams = [
      # Resume device for hibernation
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # Intel graphics optimizations (hibernate-only, no suspend workarounds needed)
      "i915.fastboot=1" # Faster boot
      "i915.enable_fbc=1" # Frame buffer compression for battery
      "i915.enable_psr=2" # PSR2 for display power savings

      # Intel CPU power management
      "intel_pstate=active"

      # Quiet boot
      "loglevel=4"
      "quiet"
      "splash"
    ];

    # SOF audio driver: Disable IMR for hibernate compatibility
    # Without this, SOF firmware fails to reload after hibernation
    # See: https://github.com/thesofproject/sof/issues/5892
    extraModprobeConfig = ''
      options snd-sof sof_debug=0x81
    '';

    loader = {
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
        editor = false;
      };
    };

    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # Hardware configuration for Intel Core i5-1130G7 (Tiger Lake)
  hardware = {
    cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = {
        General = {
          Enable = "Source,Sink,Media,Socket";
          Experimental = true;
        };
      };
    };

    # Intel Iris Xe Graphics
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver # VAAPI for Tiger Lake+
        intel-vaapi-driver # Legacy VAAPI
        libva-vdpau-driver
        libvdpau-va-gl
      ];
    };

    # IIO sensors for 2-in-1 tablet features (rotation, orientation)
    sensor.iio.enable = true;
  };

  # Networking
  networking.hostName = "oku";
  networking.useDHCP = lib.mkDefault true;
  networking.networkmanager.enable = true;

  # Greeter
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd Hyprland";
        user = "greeter";
      };
      initial_session = {
        command = "Hyprland";
        user = "simonwjackson";
      };
    };
  };

  # Enable profiles
  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true;
      gaming.enable = true;
    };

    gaming = {
      enable = true;
    };

    device = {
      role = "portable";
      capabilities = {
        battery = true;
        touchscreen = true;
        formFactor = "tablet";
      };
    };

    hyprland.enable = true;

    # Keyboard remapping (kanata - supports chords)
    keyboard = {
      enable = true;
      device = "/dev/input/event4"; # Huawei keyboard dock (by-path has colons that kanata can't parse)
      config = ''
        (defalias
          z-ctl (tap-hold 200 200 z lctl)    ;; tap: z, hold: ctrl
          v-sft (tap-hold 200 200 v lsft)    ;; tap: v, hold: shift
          m-sft (tap-hold 200 200 m lsft)    ;; tap: m, hold: shift
          '-ctl (tap-hold 200 200 ' lctl)    ;; tap: ', hold: ctrl
          spc-gui (tap-hold 200 200 spc lmet) ;; tap: space, hold: gui/super
          a-arr (tap-hold 200 200 a (layer-while-held arrows))  ;; hold: arrow layer
          s-num (tap-hold 200 200 s (layer-while-held numpad))  ;; hold: numpad layer
          d-brk (tap-hold 200 200 d (layer-while-held brackets)) ;; hold: brackets layer
          f-nav (tap-hold 200 200 f (layer-while-held fnav))    ;; hold: f-nav layer
          e-med (tap-hold 200 200 e (layer-while-held media))   ;; hold: media layer
          ;; Swap ; and : - tap gives :, with shift gives ;
          scln-swap (fork S-; (unshift ;) (lsft rsft))
          ;; When in arrows layer (A held), hold S to activate scroll layer
          s-scrl (layer-while-held scroll)
          ;; When in numpad layer (S held), hold A to activate scroll layer
          a-scrl (layer-while-held scroll)
          ;; When in arrows layer (A held), hold D to activate symbols layer
          d-sym (layer-while-held symbols)
        )

        (defsrc
          esc  grv  1    2    3    4    5    6    7    8    9    0    min  eql  bspc
          tab  q    w    e    r    t    y    u    i    o    p    [    ]    \    '
          caps a    s    d    f    g    h    j    k    l    ;    ret
          lsft 102d z    x    c    v    b    n    m    ,    .    /    rsft
          lctl lalt lmet rmet ralt rctl
          spc  up   down left rght
          f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
          mute vold volu brup brdn
        )

        (deflayer base
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   q    w    @e-med r  t    y    u    i    o    p    XX   XX   XX   XX
          XX   @a-arr @s-num @d-brk @f-nav g  h    j    k    l    @scln-swap XX
          XX   @z-ctl x  c    @v-sft ,  XX   .    @m-sft n  b    @'-ctl XX
          XX   lalt lmet rmet ralt XX
          @spc-gui XX XX XX XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer arrows
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    _    _    _    _    XX   XX   XX   XX   XX
          XX   _    @s-scrl @d-sym _  _    left down up   rght _    XX
          XX   _    _    _    _    _    _    _    _    _    _    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer numpad
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    S-3  7    8    9    S-5  XX   XX   XX   XX
          XX   @a-scrl _  _    _    _    S-=  4    5    6    min  XX
          XX   _    _    _    _    _    _    S-8  1    2    3    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer scroll
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    _    _    _    _    XX   XX   XX   XX   XX
          XX   _    _    _    _    _    home pgdn pgup end  _    XX
          XX   _    _    _    _    _    _    _    _    _    _    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer fnav
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    _    _    _    _    XX   XX   XX   XX   XX
          XX   _    _    _    _    _    bspc tab  S-tab del  _    XX
          XX   _    _    _    _    _    _    _    _    _    _    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer brackets
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    _    [    ]    _    XX   XX   XX   XX   XX
          XX   _    _    _    _    _    _    S-9  S-0  _    _    XX
          XX   _    _    _    _    _    _    _    S-[  S-]  _    _    XX
          XX   _    _    _    S-.  XX
          S-,  XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer symbols
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    S-grv /  S-\  \    S-grv XX   XX   XX   XX
          XX   _    _    _    _    _    S-6  S-2  S-7  S-4  eql  XX
          XX   _    _    _    _    _    _    _    S-/  S-1  _    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        (deflayer media
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   _    _    _    _    _    prev vold volu next XX XX XX XX XX
          XX   _    _    _    _    _    prev pp   mute next _    XX
          XX   _    _    _    _    _    _    _    brdn brup _    _    XX
          XX   _    _    _    _    XX
          _    XX   XX   XX   XX
          XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX   XX
          XX   XX   XX   XX   XX
        )

        ;; Simultaneous key chords
        (defchordsv2
          (j k) ret 50 first-release ()   ;; j+k = Enter
          (k l) esc 50 first-release ()   ;; k+l = Escape
          (l h) C-s 50 first-release ()   ;; l+h = Ctrl+S
        )
      '';
    };

    # Auto-rotation for tablet
    # auto-rotate.enable = true;

    impermanence.enable = lib.mkForce false;

    # Syncthing for knowledge sync
    syncthing = {
      enable = true;
      deviceId = "ICJAC2B-55KKGYZ-5QUYHGX-NJLJTQ2-KI4EPHO-IIIDF5F-ZY54PKY-Y46T3AR";
      folders.knowledge.path = "/snowscape/knowledge";
    };
  };

  # Use persistent SSH key for agenix (set directly to override defaults)
  age.identityPaths = lib.mkForce ["/tundra/permafrost/etc/ssh/ssh_host_rsa_key"];

  # Disable auto-cpufreq from base profile (conflicts with TLP)
  services.auto-cpufreq.enable = lib.mkForce false;

  # Ephemeral root filesystem
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = ["defaults" "size=2G" "mode=755"];
  };

  fileSystems."/tundra/permafrost".neededForBoot = true;

  # Impermanence configuration
  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/etc/NetworkManager/system-connections"
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/bluetooth"
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];

    files = [
      "/etc/machine-id"
    ];
  };

  systemd.tmpfiles.settings."10-persistent-ownership" = {
    "/tundra/permafrost/home/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0700";
    };
    "/tundra/permafrost/nix/var/nix/profiles/per-user/simonwjackson".d = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
    "/snowscape/knowledge".z = {
      user = "simonwjackson";
      group = "users";
      mode = "0755";
    };
  };

  # SSH
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
    };

    hostKeys = [
      {
        path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
  };

  # Tablet-specific services
  services = {
    # Power management (TLP for laptops/tablets)
    tlp = {
      enable = true;
      settings = {
        CPU_SCALING_GOVERNOR_ON_AC = "performance";
        CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
        CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
        CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

        # Battery charge thresholds (huawei-wmi)
        START_CHARGE_THRESH_BAT0 = 40;
        STOP_CHARGE_THRESH_BAT0 = 80;

        # WiFi power saving on battery
        WIFI_PWR_ON_AC = "off";
        WIFI_PWR_ON_BAT = "on";
      };
    };

    acpid.enable = true;
    fwupd.enable = true;
    blueman.enable = true;

    # Thermald: Intel thermal management for preventing throttling
    thermald.enable = true;

    # Touchscreen/stylus input
    libinput = {
      enable = true;
      touchpad = {
        naturalScrolling = true;
        tapping = true;
        disableWhileTyping = false;
        accelProfile = "adaptive";
      };
    };
  };

  # XDG portal paths for home-manager integration
  environment.pathsToLink = ["/share/applications" "/share/xdg-desktop-portal"];

  # Tablet utilities
  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  # Suspend-then-hibernate for battery life
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=30m
  '';

  # Lid and power button behavior
  # NOTE: Suspend doesn't work on this device - DSI panel has timing bugs on resume
  # (i915 flip_done timeout, see dmesg). Use hibernate directly instead.
  services.logind.settings.Login = {
    HandleLidSwitch = lib.mkForce "hibernate";
    HandleLidSwitchExternalPower = lib.mkForce "hibernate";
    HandlePowerKey = lib.mkForce "hibernate";
  };

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  # User configuration
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video" "input"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  system.stateVersion = "25.05";
}
