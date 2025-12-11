# ==============================================================================
# KUJU - GPD Win Mini 2025 (AMD Ryzen AI 9 HX 370)
# ==============================================================================
#
# BATTERY OPTIMIZATION NOTES:
# ---------------------------
# This config is tuned for MAXIMUM BATTERY LIFE. Key features:
# - auto-cpufreq: Automatic governor switching (powersave on battery)
# - Turbo disabled on battery (saves significant power)
# - CPU capped at 2GHz on battery (prevents power spikes)
# - USB/PCI autosuspend enabled
# - AMD GPU forced to low power on battery
# - powertop auto-tune enabled
#
# WARNING: Gaming on battery will be SLOW with default settings!
# Use the "GAMING ON BATTERY" commands below to unlock performance.
#
# ==============================================================================
# GAMING ON BATTERY (run before launching game)
# ==============================================================================
#
# ENABLE GAMING MODE:
#   # Unlock CPU (allow turbo, remove frequency cap)
#   sudo auto-cpufreq --force performance
#
#   # Unlock GPU (allow dynamic clocking)
#   echo "auto" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
#
#   # Set TDP for gaming (18-25W is good balance of performance vs battery)
#   sudo ryzenadj --stapm-limit=20000 --fast-limit=25000 --slow-limit=20000
#
# RETURN TO BATTERY SAVER (after gaming):
#   # Re-enable auto-cpufreq battery management
#   sudo auto-cpufreq --force reset
#
#   # Lock GPU to low power
#   echo "low" | sudo tee /sys/class/drm/card*/device/power_dpm_force_performance_level
#
#   # Set ultra-low TDP
#   sudo ryzenadj --stapm-limit=10000 --fast-limit=12000 --slow-limit=10000
#
# ==============================================================================
# AFTER FIRST BOOT
# ==============================================================================
#
# 1. Calibrate fan control sensors:
#      sudo sensors-detect    # Detect available sensors
#      sudo pwmconfig         # Generate fan curve config
#    Then update hardware.fancontrol.config below with correct hwmon paths
#
# 2. Test display rotation:
#    If screen is rotated wrong, adjust transform value in home.nix:
#      transform,1 = 90° clockwise
#      transform,3 = 90° counter-clockwise
#
# 3. Check power consumption:
#      sudo powertop          # Analyze power usage
#      auto-cpufreq --stats   # Check CPU frequency/governor
#
# ==============================================================================
# TDP REFERENCE (ryzenadj values in milliwatts)
# ==============================================================================
#
#   ULTRA-LOW (reading, browsing):
#     ryzenadj --stapm-limit=8000 --fast-limit=10000 --slow-limit=8000
#
#   BATTERY SAVER (light tasks):
#     ryzenadj --stapm-limit=10000 --fast-limit=12000 --slow-limit=10000
#
#   BALANCED (general use):
#     ryzenadj --stapm-limit=15000 --fast-limit=18000 --slow-limit=15000
#
#   GAMING ON BATTERY:
#     ryzenadj --stapm-limit=20000 --fast-limit=25000 --slow-limit=20000
#
#   GAMING PLUGGED IN:
#     ryzenadj --stapm-limit=28000 --fast-limit=35000 --slow-limit=28000
#
#   MAX PERFORMANCE (benchmarks, thermals will spike):
#     ryzenadj --stapm-limit=35000 --fast-limit=40000 --slow-limit=35000
#
# ==============================================================================
{
  config,
  pkgs,
  lib,
  inputs,
  modulesPath,
  ...
}: let
  swayGamingConfig = pkgs.writeText "sway-gaming-config" ''
    # Gaming-optimized sway config (minimal, no bar, Steam autostart)

    ### Variables
    set $mod Mod4
    set $term foot

    ### Autostart Steam
    exec steam

    ### Key bindings
    bindsym $mod+Return exec $term
    bindsym $mod+Shift+q kill
    bindsym $mod+f fullscreen
  '';
in {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ./disko.nix
    inputs.gpd-fan-driver.nixosModules.default
  ];

  # ============================================================================
  # BOOT CONFIGURATION - AMD Ryzen AI 9 HX 370 (Zen 5) Gaming Handheld
  # ============================================================================
  # Reference: nixos-hardware has gpd-win-max-2-2023 module, but 2025 model
  # has different quirks (AMD Ryzen AI 9 HX 370 vs older Intel/AMD models)
  # ============================================================================
  boot = {
    # Zen kernel for gaming performance and latest hardware support
    # Requires 6.12+ for proper AMD Strix GPU support
    kernelPackages = pkgs.linuxPackages_zen;

    initrd = {
      availableKernelModules = [
        "nvme" # NVMe SSD support
        "xhci_pci" # USB 3.x controller
        "thunderbolt" # USB4/Thunderbolt support
        "usb_storage" # USB storage devices
        "sd_mod" # SD card reader
      ];
      kernelModules = ["amdgpu"]; # Early KMS for AMD Radeon 890M (Strix/RDNA 3.5)
    };

    kernelModules = [
      "kvm-amd" # AMD virtualization
      "amdgpu" # AMD graphics driver
      "iwlwifi" # Intel Wi-Fi 6E AX210
      "btusb" # Bluetooth support
      "gpd-fan" # GPD fan control - load early to minimize loud fan during boot
    ];

    # Blacklist conflicting modules
    blacklistedKernelModules = [
      # BMI160 conflicts with BMI260 IMU (GPD uses BMI260, needs IIO subsystem)
      "bmi160_spi"
      "bmi160_i2c"
      "bmi160_core"
      # sp5100_tco (AMD watchdog) conflicts with i2c_piix4 SMBus
      "sp5100_tco"
      # i2c_piix4 causes SMBus timeout errors on AMD Ryzen AI 9 HX 370
      # Only loses SPD EEPROM access (decode-dimms) - dmidecode still works via SMBIOS
      "i2c_piix4"
    ];

    extraModulePackages = [];

    # Kernel parameters optimized for AMD Strix gaming handheld
    kernelParams = [
      # Resume device for hibernation (must match swap partition)
      "resume=/dev/disk/by-partlabel/disk-main-swap"

      # ========================================================================
      # AMD GPU optimizations for Radeon 890M (Strix/RDNA 3.5)
      # ========================================================================
      # CRITICAL: Fix VCN ring timeout issues on RDNA 3.5
      # Disables VCN (Video Core Next) DPG (Dynamic Power Gating)
      # Without this, GPU may hang during video decode/encode operations
      "amdgpu.ppfeaturemask=0xfffd7fff"

      "amdgpu.gpu_recovery=1" # Enable GPU hang recovery
      "amdgpu.dc=1" # Display Core for better display
      "amdgpu.dpm=1" # Dynamic Power Management

      # ========================================================================
      # AMD CPU power management (Zen 5 architecture)
      # ========================================================================
      "amd_pstate=active" # Active P-state driver for better power/performance
      "processor.max_cstate=8" # Allow deeper C-states for better idle power

      # ========================================================================
      # Sleep/Suspend Configuration (AMD Ryzen AI 9 HX 370)
      # ========================================================================
      # CRITICAL: AMD dropped S3 sleep support on newer CPUs
      # Only s2idle (suspend-to-idle) works reliably on Ryzen AI 9 HX 370
      # Using 'deep' (S3) will cause sleep failures and potential hangs
      "mem_sleep_default=s2idle"

      # NVMe power state fix - critical for AMD sleep/wake reliability
      # Prevents NVMe drive from entering problematic power states during suspend
      "nvme_core.default_ps_max_latency_us=0"

      # ========================================================================
      # Display Configuration
      # ========================================================================
      "fbcon=nodefer" # Earlier framebuffer initialization

      # ========================================================================
      # Boot Configuration - MAXIMUM SPEED
      # ========================================================================
      "loglevel=3" # Reduce kernel logging (errors and warnings only)
      "quiet"
      "rd.systemd.show_status=auto" # Only show status on slow boot
      "rd.udev.log_level=3" # Reduce udev logging

      # Disable unnecessary kernel features for faster boot
      "nowatchdog" # Disable watchdog (saves ~0.5s)
      "nmi_watchdog=0" # Disable NMI watchdog
      "modprobe.blacklist=iTCO_wdt" # Blacklist Intel watchdog

      # Faster console
      "vt.global_cursor_default=0" # Hide cursor during boot
    ];

    # systemd-boot (UEFI) - simpler than GRUB for single-boot UEFI systems
    loader = {
      # Skip boot menu for fastest boot - hold space to show menu
      timeout = 0;
      efi = {
        canTouchEfiVariables = true;
        efiSysMountPoint = "/boot";
      };
      systemd-boot = {
        enable = true;
        configurationLimit = 10; # Limit generations to save space
        editor = false; # Disable boot editor for security
      };
    };

    # Resume from hibernate
    resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
  };

  # ============================================================================
  # HARDWARE CONFIGURATION - AMD Ryzen AI 9 HX 370 + Radeon 890M
  # ============================================================================
  hardware = {
    cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    enableRedistributableFirmware = true;

    # Bluetooth configuration (Intel AX210 integrated)
    bluetooth = {
      enable = true;
      powerOnBoot = true; # Power on Bluetooth adapter on boot
      # Enable experimental features for better codec support (headphones, controllers)
      settings = {
        General = {
          Experimental = true;
          # Note: Audio profiles (Source,Sink,Media) are handled by PipeWire, not main.conf
        };
      };
    };

    # AMD Radeon 890M Graphics (Strix/RDNA 3.5 integrated GPU)
    graphics = {
      enable = true;
      enable32Bit = true; # Essential for gaming (32-bit games/libraries)
      extraPackages = with pkgs; [
        # Video acceleration
        libva
        libvdpau-va-gl
      ];
    };

    # Enable AMD GPU OpenCL support (for compute workloads)
    amdgpu.opencl.enable = true;
  };

  # ============================================================================
  # NETWORKING
  # ============================================================================
  networking = {
    hostName = "kuju";
    useDHCP = lib.mkDefault true;
    networkmanager.enable = true;
    networkmanager.wifi.powersave = false; # Disable WiFi powersave for gaming
  };

  # ============================================================================
  # MOUNTAINOUS CONFIGURATION - Gaming Handheld Profile
  # ============================================================================
  mountainous = {
    profiles = {
      base.enable = true;
      laptop.enable = true; # Portable device features (battery, power management)
      gaming.enable = true; # Gaming-specific features
    };

    # Device configuration: portable gaming handheld
    device = {
      role = "portable"; # Usage: mobile gaming, battery-conscious
      capabilities = {
        battery = true;
        touchscreen = false; # GPD Win Max 2 style has keyboard/trackpad, not touchscreen
        formFactor = "handheld";
      };
    };

    # Ensure required directories exist
    directories.paths = {
      "/snowscape/knowledge" = {
        owner = "simonwjackson";
        group = "users";
        mode = "0755";
        parents = true; # Also create /snowscape if needed
      };
    };

    # Impermanence - ephemeral root with persistent storage
    # Using mountainous impermanence module for managed persistence
    impermanence = {
      enable = true;
      persistFsType = "btrfs";

      # Create @nix subvolume for Nix store (already in disko.nix)
      persistNixStore = true;

      # Persist logs for debugging gaming issues
      persistLogs = true;

      # Extra directories beyond the base
      extraDirectories = [
        {
          directory = "/tundra/igloo";
          user = "simonwjackson";
          group = "users";
          mode = "0700";
        }
      ];
    };

    # Hyprland window manager
    hyprland.enable = true;

    # Gaming - local Steam install only
    gaming = {
      enable = true;
      steamPrefs = {
        enable = true;
        steamId = "80924811";
        friends.autoSignIn = "offline";
        remotePlay.enable = false;
        compatibility.defaultTool = "GE-Proton";
        controller.guideButtonFocusesSteam = false;
        shaderCache = {
          enablePreCaching = false;
          enableBackgroundProcessing = false;
        };
      };
    };

    # Syncthing for knowledge sync
    syncthing = {
      enable = true;
      deviceId = "JD7WTBJ-N4R623A-7EYMYTM-3PK4NS4-LGEE2GJ-PVE3XO3-3RLFXMX-R53EEQU";
      folders.knowledge.path = "/snowscape/knowledge";
    };

    # Keyboard remapping via Kanata
    # Hold F + H/J/K/L = Backspace/Tab/Shift+Tab/Delete
    # Hold A + H/J/K/L = Arrow keys (left/down/up/right)
    # Hold A, then also hold S + H/J/K/L = Home/PageDown/PageUp/End
    # Hold S = Numpad layer (y=# u=7 i=8 o=9 p=% h=+ j=4 k=5 l=6 ;=- n=* m=1 ,=2 .=3)
    # Hold Z or . = Ctrl, Hold V or N = Shift
    # Swap ; and : (tap ; gives :, shift+; gives ;)
    # Simultaneous: JK = Enter, KL = Escape, HL = Ctrl+S
    keyboard = {
      enable = true;
      device = "/dev/input/by-path/platform-i8042-serio-0-event-kbd";
      config = ''
        (defsrc
          a s f h j k l z v n . y u i o p ; m , spc del
        )

        (defalias
          a (tap-hold 200 200 a (layer-while-held arrows))
          s (tap-hold 200 200 s (layer-while-held numpad))
          f (tap-hold 200 200 f (layer-while-held nav))
          ;; Space tap, GUI/Super hold
          spc (tap-hold 200 200 spc lmet)
          ;; When in arrows layer (A held), hold S to activate scroll layer
          s-scrl (layer-while-held scroll)
          ;; When in numpad layer (S held), hold A to activate scroll layer
          a-scrl (layer-while-held scroll)
          ;; Ctrl on hold
          z (tap-hold 200 200 z lctl)
          dot (tap-hold 200 200 . lctl)
          ;; Shift on hold
          v (tap-hold 200 200 v lsft)
          n (tap-hold 200 200 n lsft)
          ;; Swap ; and : - tap gives :, with shift gives ;
          scln-swap (fork S-; (unshift ;) (lsft rsft))
        )

        (deflayer base
          @a @s @f h j k l @z @v @n @dot y u i o p @scln-swap m , @spc A-esc
        )

        (deflayer nav
          _ _ _ bspc tab S-tab del _ _ _ _ _ _ _ _ _ _ _ _ _ _
        )

        (deflayer arrows
          _ @s-scrl _ left down up right _ _ _ _ _ _ _ _ _ _ _ _ _ _
        )

        (deflayer numpad
          @a-scrl _ _ S-= 4 5 6 _ _ S-8 3 S-3 7 8 9 S-5 min 1 2 _ _
        )

        (deflayer scroll
          _ _ _ home pgdn pgup end _ _ _ _ _ _ _ _ _ _ _ _ _ _
        )

        (defchordsv2
          (j k) ret 50 first-release ()
          (k l) esc 50 first-release ()
          (h l) C-s 50 first-release ()
        )
      '';
    };
  };

  # ============================================================================
  # SERVICES - Gaming Handheld Optimizations
  # ============================================================================

  # Disable nscd - restarts on every resolv.conf change causing boot loop
  # Name resolution works via systemd-resolved/NetworkManager without nscd
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [];

  services = {
    # SSD optimization (TRIM for NVMe)
    fstrim.enable = true;

    # ACPI event handling (power button, lid)
    acpid.enable = true;

    # Firmware updates
    fwupd.enable = true;

    # Blueman: Bluetooth manager GUI (for pairing controllers, headphones)
    blueman.enable = true;

    # Thunderbolt/USB4 support
    hardware.bolt.enable = true;

    # Disable SDDM (use greetd instead for TUI login)
    displayManager.sddm.enable = lib.mkForce false;

    # TUI login manager with auto-login to Hyprland on TTY1
    greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.tuigreet}/bin/tuigreet --time --cmd start-hyprland";
          user = "greeter";
        };
        initial_session = {
          command = "start-hyprland";
          user = "simonwjackson";
        };
      };
    };
  };

  # ============================================================================
  # GREETD BOOT OPTIMIZATION - Remove network dependency for fastest boot
  # ============================================================================
  # systemd-user-sessions waits for network.target and we can't easily remove it.
  # Solution: Make greetd NOT wait for systemd-user-sessions at all.
  # greetd just needs basic.target to launch Hyprland - network is not required.
  systemd.services.greetd = {
    after = lib.mkForce ["basic.target"];
    wants = lib.mkForce [];
    requires = lib.mkForce [];
  };

  # Evsieve: Remap Xbox button (BTN_MODE) to keyboard key for Hyprland binding
  # Uses raw GPD controller directly (no HHD - simpler and more stable)
  systemd.services.xbox-button-remap = {
    description = "Remap Xbox button to keyboard key";
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "simple";
      Restart = "on-failure";
      RestartSec = "3s";
      ExecStart = pkgs.writeShellScript "xbox-remap" ''
        # Find raw GPD controller (X-Box 360 pad)
        find_gpd_controller() {
          ${pkgs.gawk}/bin/awk '
            /^N: Name="Microsoft X-Box 360 pad"/ { found=1 }
            found && /^H: Handlers=/ {
              match($0, /event[0-9]+/)
              if (RSTART > 0) {
                print "/dev/input/" substr($0, RSTART, RLENGTH)
                exit
              }
            }
          ' /proc/bus/input/devices
        }

        echo "Waiting for GPD controller..."
        while true; do
          GPD_DEV=$(find_gpd_controller)
          if [ -n "$GPD_DEV" ] && [ -e "$GPD_DEV" ]; then
            break
          fi
          sleep 1
        done
        echo "Found GPD controller at $GPD_DEV"

        # Intercept BTN_MODE (Xbox button), emit as XF86Launch6 keyboard key
        # Pass all other controller events through unchanged
        exec ${pkgs.evsieve}/bin/evsieve \
          --input "$GPD_DEV" grab \
          --map btn:mode key:f15 \
          --output key:f15 create-link=/dev/input/by-id/xbox-button-keyboard name="Xbox Button Keyboard" \
          --output name="GPD Controller"
      '';
    };
  };

  # OBS Studio with virtual camera
  programs.obs-studio = {
    enable = true;
    enableVirtualCamera = true;
  };

  # Mosh - mobile shell for unstable connections
  programs.mosh.enable = true;

  # Sway window manager (on TTY2)
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # ============================================================================
  # THERMAL/FAN & TDP CONFIGURATION - Quiet Operation with Dynamic Performance
  # ============================================================================
  # Goal: Keep fan quiet as long as possible while allowing dynamic TDP
  #
  # Strategy:
  # 1. Use power-profiles-daemon for system-wide power profiles
  # 2. Use ryzenadj for manual TDP adjustments when needed
  # 3. Use fancontrol with gpd-fan driver for custom fan curve
  # ============================================================================

  # IMPORTANT: power-profiles-daemon conflicts with auto-cpufreq
  # We use auto-cpufreq for maximum battery optimization
  services.power-profiles-daemon.enable = false;

  # Tools for TDP/fan control
  # - ryzenadj: manual TDP control (doesn't lock to constant TDP)
  #   Usage: ryzenadj --stapm-limit=15000 --fast-limit=20000 --slow-limit=18000
  # - lm_sensors: sensor detection and monitoring
  environment.systemPackages = with pkgs; [
    ryzenadj
    lm_sensors
    # Cage compositor for nested Sway gaming session
    cage
    (writeShellScriptBin "game-session" ''
      # Launch Sway inside cage for gaming with custom config (no bar)
      # Uses systemd scope for easy freeze/unfreeze via game-session-freeze/thaw
      exec ${systemd}/bin/systemd-run --user --scope --unit=game-session \
        ${cage}/bin/cage -s -- sway -c ${swayGamingConfig}
    '')
    (writeShellScriptBin "game-session-freeze" ''
      ${systemd}/bin/systemctl --user freeze game-session.scope 2>/dev/null
    '')
    (writeShellScriptBin "game-session-thaw" ''
      ${systemd}/bin/systemctl --user thaw game-session.scope 2>/dev/null
    '')
    (writeShellScriptBin "game-session-monitor" ''
      # Auto freeze/thaw game-session based on workspace 10 focus
      # Thaw when on workspace 10, freeze when leaving
      GAME_WORKSPACE=10
      LAST_STATE=""

      update_state() {
        local current_ws="$1"
        if [ "$current_ws" = "$GAME_WORKSPACE" ] && [ "$LAST_STATE" != "thaw" ]; then
          ${systemd}/bin/systemctl --user thaw game-session.scope 2>/dev/null && LAST_STATE="thaw"
        elif [ "$current_ws" != "$GAME_WORKSPACE" ] && [ "$LAST_STATE" != "freeze" ]; then
          ${systemd}/bin/systemctl --user freeze game-session.scope 2>/dev/null && LAST_STATE="freeze"
        fi
      }

      # Get initial workspace and set state
      INITIAL_WS=$(${pkgs.hyprland}/bin/hyprctl activeworkspace -j | ${pkgs.jq}/bin/jq -r '.id')
      update_state "$INITIAL_WS"

      # Monitor workspace changes via Hyprland socket
      ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" | while read -r line; do
        if [[ "$line" == workspace\>\>* ]]; then
          WS="''${line#workspace>>}"
          update_state "$WS"
        fi
      done
    '')
  ];

  # ============================================================================
  # FAN CONTROL - GPD Fan Driver + Quiet Curve
  # ============================================================================
  # Uses external gpd-fan-driver module (kernel 6.18+ will have it natively)
  # https://github.com/Cryolitia/gpd-fan-driver
  hardware.gpd-fan.enable = true;

  # Early fan silence - runs ASAP to quiet the fan before full fancontrol starts
  # This is a oneshot that runs very early in boot to minimize loud fan time
  systemd.services.gpd-fan-early-quiet = {
    description = "GPD Fan Early Quiet (minimize boot noise)";
    wantedBy = ["sysinit.target"];
    after = ["systemd-modules-load.service"];
    before = ["basic.target"];
    unitConfig = {
      DefaultDependencies = false;
    };
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "gpd-fan-early-quiet" ''
        # Wait briefly for hwmon to appear (max 5 seconds)
        for i in $(seq 1 50); do
          for hwmon in /sys/class/hwmon/hwmon*; do
            if [[ -f "$hwmon/name" ]] && [[ "$(cat "$hwmon/name" 2>/dev/null)" == "gpdfan" ]]; then
              # Found it - set to minimum PWM immediately
              echo 1 > "$hwmon/pwm1_enable" 2>/dev/null || true
              echo 0 > "$hwmon/pwm1" 2>/dev/null || true
              echo "Fan set to quiet mode via $hwmon"
              exit 0
            fi
          done
          sleep 0.1
        done
        echo "Warning: gpdfan hwmon not found within 5 seconds"
      '';
    };
  };

  # Dynamic fancontrol - finds hwmon devices by name at runtime
  # Survives hwmon number changes across reboots
  systemd.services.gpd-fancontrol = {
    description = "GPD Dynamic Fan Control";
    wantedBy = ["multi-user.target"];
    after = ["systemd-modules-load.service" "gpd-fan-early-quiet.service"];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.gpd-fancontrol}/bin/gpd-fancontrol";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  # ============================================================================
  # POWER MANAGEMENT - MAXIMUM BATTERY OPTIMIZATION
  # ============================================================================
  # Note: suspend-then-hibernate is handled by mountainous.hybrid-sleep
  # (enabled via laptop profile) - no need to configure logind manually

  # Auto-cpufreq: Automatic CPU frequency scaling for battery life
  # Much better than static governors - adapts dynamically
  services.auto-cpufreq = {
    enable = true;
    settings = {
      battery = {
        governor = "powersave";
        turbo = "never"; # Disable turbo on battery for max runtime
        energy_performance_preference = "power";
        scaling_min_freq = 400000; # Allow CPU to clock down to 400MHz
        scaling_max_freq = 2000000; # Cap at 2GHz on battery
      };
      charger = {
        governor = "schedutil"; # Dynamic scaling when plugged in
        turbo = "auto";
        energy_performance_preference = "balance_performance";
      };
    };
  };

  # Powertop auto-tune: Enable all power saving tunables
  powerManagement.powertop.enable = true;

  # Enable power management
  powerManagement.enable = true;

  # Audio power saving (Intel HDA codec)
  boot.extraModprobeConfig = ''
    options snd_hda_intel power_save=1
  '';

  # USB autosuspend and other power tweaks via udev
  services.udev.extraRules = ''
    # Backlight control - allow video group to write
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chgrp video /sys/class/backlight/%k/brightness"
    ACTION=="add", SUBSYSTEM=="backlight", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys/class/backlight/%k/brightness"

    # Set fan to quiet immediately when device appears (before fancontrol starts)
    # Uses %S (sysfs path) and %p (device path) for reliable path construction
    ACTION=="add", SUBSYSTEM=="hwmon", ATTR{name}=="gpdfan", RUN+="${pkgs.bash}/bin/bash -c 'echo 1 > %S%p/pwm1_enable 2>/dev/null; echo 0 > %S%p/pwm1 2>/dev/null || true'"

    # Enable USB autosuspend for actual USB devices (not interface nodes)
    # TEST ensures the attribute exists before attempting to write
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/autosuspend_delay_ms", ATTR{power/autosuspend_delay_ms}="1000"
    ACTION=="add", SUBSYSTEM=="usb", TEST=="power/control", ATTR{power/control}="auto"

    # SATA link power management
    ACTION=="add", SUBSYSTEM=="scsi_host", KERNEL=="host*", TEST=="link_power_management_policy", ATTR{link_power_management_policy}="med_power_with_dipm"

    # PCI power management
    ACTION=="add", SUBSYSTEM=="pci", TEST=="power/control", ATTR{power/control}="auto"

    # AMD GPU power saving - only match main card device (card0, card1), not outputs (card1-DP-1, etc.)
    ACTION=="add", SUBSYSTEM=="drm", KERNEL=="card[0-9]", TEST=="device/power_dpm_force_performance_level", ATTR{device/power_dpm_force_performance_level}="low"
  '';

  # WiFi power saving (re-enable on battery - was disabled for gaming)
  # NOTE: This is now handled dynamically by auto-cpufreq / scripts
  # networking.networkmanager.wifi.powersave = true; # Conflicts with gaming profile

  # Additional Steam configuration (base Steam handled by gaming profile)
  programs.steam = {
    remotePlay.openFirewall = true;
  };

  # Steam button handler - Xbox button via evsieve remap
  mountainous.gaming.steamButton = {
    enable = true;
    keybind = ", XF86Launch6"; # Xbox button (BTN_MODE) remapped via evsieve
    useSpecialWorkspace = false; # Steam goes to workspace 10, not a special overlay
  };

  # ============================================================================
  # USER CONFIGURATION
  # ============================================================================
  users.users.simonwjackson = {
    isNormalUser = true;
    extraGroups = ["wheel" "networkmanager" "video"];
    openssh.authorizedKeys.keyFiles = [
      ../../../modules/nixos/user/id_rsa.pub
    ];
  };

  # ============================================================================
  # BOOT SPEED OPTIMIZATIONS - MAXIMUM AGGRESSION
  # ============================================================================
  # Goal: Get to Hyprland in under 2 seconds userspace time
  # Strategy: Defer EVERYTHING that isn't needed for display

  # --------------------------------------------------------------------------
  # NETWORK SERVICES - All deferred (not needed for Hyprland)
  # --------------------------------------------------------------------------

  # Defer NetworkManager-wait-online completely (often blocks boot)
  systemd.services.NetworkManager-wait-online.enable = lib.mkForce false;

  # Defer tailscaled daemon (608ms)
  systemd.services.tailscaled = {
    wantedBy = lib.mkForce [];
    before = lib.mkForce [];
  };
  systemd.timers.tailscaled-deferred = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "5s";
      Unit = "tailscaled.service";
    };
  };

  # Defer tailscaled-autoconnect (6.5s)
  systemd.services.tailscaled-autoconnect = {
    wantedBy = lib.mkForce [];
    before = lib.mkForce [];
  };
  systemd.timers.tailscaled-autoconnect-deferred = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "8s";
      Unit = "tailscaled-autoconnect.service";
    };
  };

  # --------------------------------------------------------------------------
  # POWER/HARDWARE SERVICES - Deferred (can tune after login)
  # --------------------------------------------------------------------------

  # Defer powertop (2.4s)
  systemd.services.powertop.wantedBy = lib.mkForce [];
  systemd.timers.powertop = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "30s";
      Unit = "powertop.service";
    };
  };

  # Defer bolt (268ms) - Thunderbolt auth not needed immediately
  systemd.services."bolt".wantedBy = lib.mkForce [];
  systemd.timers.bolt-deferred = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "10s";
      Unit = "bolt.service";
    };
  };

  # Defer fwupd - firmware updates definitely not needed at boot
  systemd.services.fwupd.wantedBy = lib.mkForce [];

  # --------------------------------------------------------------------------
  # SYNC SERVICES - Deferred
  # --------------------------------------------------------------------------

  # Defer syncthing-init (149ms)
  systemd.services.syncthing-init = {
    wantedBy = lib.mkForce [];
    before = lib.mkForce [];
  };
  systemd.timers.syncthing-init-deferred = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnBootSec = "15s";
      Unit = "syncthing-init.service";
    };
  };

  # --------------------------------------------------------------------------
  # OPTIONAL SERVICES - Defer or disable
  # --------------------------------------------------------------------------

  # Defer ModemManager (78ms) - not using cellular
  systemd.services.ModemManager.wantedBy = lib.mkForce [];

  # Defer geoclue (99ms) - location services not critical
  systemd.services.geoclue.wantedBy = lib.mkForce [];

  # --------------------------------------------------------------------------
  # SYSTEMD OPTIMIZATIONS
  # --------------------------------------------------------------------------

  # Aggressive timeouts - fail fast, don't hang boot
  systemd.settings.Manager = {
    DefaultTimeoutStartSec = "5s";
    DefaultTimeoutStopSec = "5s";
    DefaultDeviceTimeoutSec = "5s";
  };

  # Disable systemd-networkd-wait-online if present
  systemd.network.wait-online.enable = false;

  system.stateVersion = "25.05";
}
