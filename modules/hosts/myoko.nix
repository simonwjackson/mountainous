# Host myoko: ASUS Zenbook A16 UX3607OA on its internal NVMe disk.
#
# The disk is not managed by the shared whole-disk layer. Qualcomm platform
# firmware occupies partitions 1 to 11, and the factory ESP is partition 12.
# The guarded installer reclaims only the Windows partitions after those.
{
  nixos.hosts.myoko = {
    system = "aarch64-linux";
    layers = [
      "base"
      "desktop"
      "glymur"
      "myoko-disk"
    ];

    module = {
      config,
      lib,
      pkgs,
      ...
    }: let
      # This file comes from this laptop's backed-up Windows driver store.
      # Public A16 board containers differ from it. Keep the private binary
      # outside Git and require its exact content on the native builder.
      wifiBoard = pkgs.requireFile {
        name = "bdwlan_qcc2072_1p0_ncm820A.elf";
        sha256 = "960e9e93da708f5e1086ce15d82d3e44d846ec9441eac40e1725467d357965d8";
        message = ''
          Import Myoko's factory QCC2072 board file on the build machine:
            nix-store --add-fixed sha256 /path/to/bdwlan_qcc2072_1p0_ncm820A.elf
          See docs/research/myoko-post-boot-hardware.md for the source and hash.
        '';
      };

      myoko-power-sync = pkgs.writeShellScriptBin "myoko-power-sync" ''
        set -eu

        is_ac() {
          for psy in /sys/class/power_supply/qcom-battmgr-ac \
                     /sys/class/power_supply/qcom-battmgr-usb \
                     /sys/class/power_supply/ucsi-source-psy-pmic_glink.ucsi.01 \
                     /sys/class/power_supply/ucsi-source-psy-pmic_glink.ucsi.02; do
            if [ -f "$psy/online" ] && [ "$(cat "$psy/online" 2>/dev/null)" = "1" ]; then
              return 0
            fi
          done
          return 1
        }

        if is_ac; then
          echo default > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
          target_mode="2880x1800@120"
        else
          echo powersupersave > /sys/module/pcie_aspm/parameters/policy 2>/dev/null || true
          for d in /sys/bus/pci/devices/*; do
            [ -f "$d/power/control" ] && echo auto > "$d/power/control" 2>/dev/null || true
          done
          target_mode="2880x1800@60"
        fi

        uid=$(${pkgs.coreutils}/bin/id -u simon 2>/dev/null || echo 1000)
        hypr_socket="/run/user/$uid/hypr"
        if [ -d "$hypr_socket" ]; then
          cur_mode=$(${pkgs.util-linux}/bin/runuser -u simon -- env XDG_RUNTIME_DIR="/run/user/$uid" WAYLAND_DISPLAY=wayland-1 \
            ${config.programs.hyprland.package}/bin/hyprctl --instance 0 monitors 2>/dev/null | ${pkgs.gnugrep}/bin/grep -A 1 "Monitor eDP-1" | ${pkgs.gnugrep}/bin/grep -o "[0-9]\+x[0-9]\+@[0-9\.]\+" || true)
          if [ -n "$cur_mode" ] && [[ "$cur_mode" != *"$target_mode"* ]]; then
            ${pkgs.util-linux}/bin/runuser -u simon -- env XDG_RUNTIME_DIR="/run/user/$uid" WAYLAND_DISPLAY=wayland-1 \
              ${config.programs.hyprland.package}/bin/hyprctl --instance 0 eval "hl.monitor({ output = \"eDP-1\", mode = \"$target_mode\", position = \"0x0\", scale = \"1.5\" })" || true
            ${pkgs.util-linux}/bin/runuser -u simon -- env XDG_RUNTIME_DIR="/run/user/$uid" WAYLAND_DISPLAY=wayland-1 \
              ${config.programs.hyprland.package}/bin/hyprctl --instance 0 dispatch 'hl.dsp.dpms({ action = "on" })' || true
          fi
        fi
      '';

      myoko-power-logger = pkgs.writeShellScriptBin "myoko-power-logger" ''
        set -eu

        log_file="/var/log/myoko-power.log"
        state_dir="/run/myoko-power-logger"
        mkdir -p "$state_dir"

        ts=$(${pkgs.coreutils}/bin/date -u +"%Y-%m-%dT%H:%M:%SZ")

        bat_path="/sys/class/power_supply/qcom-battmgr-bat"
        if [ -d "$bat_path" ]; then
          status=$(cat "$bat_path/status" 2>/dev/null || echo "Unknown")
          e_now=$(cat "$bat_path/energy_now" 2>/dev/null || echo "0")
          e_full=$(cat "$bat_path/energy_full" 2>/dev/null || echo "1")
          p_raw=$(cat "$bat_path/power_now" 2>/dev/null || echo "0")
          pct=$(${pkgs.gawk}/bin/awk -v now="$e_now" -v full="$e_full" 'BEGIN{ if (full > 0) printf "%.1f", (now/full)*100; else printf "0" }')
          power_w=$(${pkgs.gawk}/bin/awk -v p="$p_raw" 'BEGIN{ if (p < 0) p = -p; printf "%.2f", p / 1e6 }')
        else
          status="NoBat"
          pct="0"
          power_w="0.00"
        fi

        f0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
        f6=$(cat /sys/devices/system/cpu/cpu6/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
        f12=$(cat /sys/devices/system/cpu/cpu12/cpufreq/scaling_cur_freq 2>/dev/null || echo 0)
        cpu_freqs="c0:''${f0}k c6:''${f6}k c12:''${f12}k"

        top_procs=$(${pkgs.procps}/bin/ps -eo comm,%cpu --sort=-%cpu | ${pkgs.gawk}/bin/awk 'NR>1 && $2>0.0 { printf "%s:%.1f%% ", $1, $2 }' | ${pkgs.gawk}/bin/awk '{print $1, $2, $3}')

        cur_irqs="$state_dir/irqs.txt"
        prev_irqs="$state_dir/irqs.prev"
        ${pkgs.gawk}/bin/awk 'NR>1 {
          sum = 0
          for (i=2; i<=NF; i++) {
            if ($i ~ /^[0-9]+$/) sum += $i; else break
          }
          desc = ""; for (j=i; j<=NF; j++) desc = desc " " $j;
          if (sum > 0) print $1, sum, desc
        }' /proc/interrupts > "$cur_irqs"

        top_irqs=""
        if [ -f "$prev_irqs" ]; then
          top_irqs=$(${pkgs.gawk}/bin/awk '
          NR==FNR { prev[$1] = $2; next }
          {
            diff = $2 - prev[$1]
            if (diff > 0) {
              desc = $3
              print diff, $1, desc
            }
          }
          ' "$prev_irqs" "$cur_irqs" | sort -rn | head -3 | ${pkgs.gawk}/bin/awk '{printf "%s(%s):+%d ", $2, $3, $1}')
        fi
        cp "$cur_irqs" "$prev_irqs"

        entry="[$ts] bat:''${status} ''${pct}% ''${power_w}W | cpu:''${cpu_freqs} | procs:''${top_procs} | irqs:''${top_irqs}"
        echo "$entry" >> "$log_file"
      '';
    in {
      nixpkgs.config.allowUnfreePredicate = pkg:
        lib.getName pkg == "bdwlan_qcc2072_1p0_ncm820A.elf";

      # ath12k tries board.bin after both board-2.bin key lookups fail.
      # This scopes the fallback to Myoko and leaves upstream board-2.bin
      # and its regulatory data unchanged. No driver reload runs on activation.
      hardware.firmware = [
        (pkgs.runCommand "myoko-qcc2072-board" {
            # Keep this 125288-byte file readable for the installed hash check.
            passthru.compressFirmware = false;
          } ''
            install -Dm644 ${wifiBoard} \
              "$out/lib/firmware/ath12k/QCC2072/hw1.0/board.bin"
            bash ${../../scripts/test-myoko-wifi-firmware} "$out/lib/firmware"
          '')
      ];

      # Match the display sequence that survived the probe. Alias loading can
      # otherwise race the three drivers during udev coldplug. An explicit
      # modprobe still works for a blacklisted module.
      boot.blacklistedKernelModules = [
        "gpucc-glymur"
        "gxclkctl-kaanapali"
        "msm"
      ];

      # Preserve the GPU-to-GMU dependency until the ordered display service
      # runs during stage 2. Force PCIe ASPM powersupersave for battery life.
      boot.kernelParams = [
        "deferred_probe_timeout=300"
        "pcie_aspm=force"
        "pcie_aspm.policy=powersupersave"
      ];

      # Enable power-profiles-daemon for userspace power management
      services.power-profiles-daemon.enable = true;

      environment.systemPackages = [
        myoko-power-sync
        myoko-power-logger
      ];

      services.udev.extraRules = ''
        # Enable runtime PM for all PCI devices (Wi-Fi 7 and NVMe endpoints)
        ACTION=="add", SUBSYSTEM=="pci", ATTR{power/control}="auto"

        # Apply battery vs AC power profiles and display refresh rates on power events
        SUBSYSTEM=="power_supply", RUN+="${myoko-power-sync}/bin/myoko-power-sync"
      '';

      systemd.services.myoko-power-sync = {
        description = "Synchronize hardware power settings with power source";
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${myoko-power-sync}/bin/myoko-power-sync";
          RemainAfterExit = true;
        };
      };

      systemd.services.myoko-power-logger = {
        description = "Periodic power consumption and wakeups logger";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${myoko-power-logger}/bin/myoko-power-logger";
        };
      };

      systemd.timers.myoko-power-logger = {
        description = "Run myoko power logger every 60 seconds";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnBootSec = "30s";
          OnUnitActiveSec = "60s";
        };
      };

      services.logrotate.settings.myoko-power = {
        files = "/var/log/myoko-power.log";
        frequency = "weekly";
        rotate = 4;
        compress = true;
        missingok = true;
        notifempty = true;
      };

      systemd.services.myoko-display-modules = {
        description = "Load the myoko display dependency chain in order";
        wantedBy = ["multi-user.target"];
        requiredBy = ["greetd.service"];
        before = ["greetd.service"];
        path = [pkgs.kmod];
        script = ''
          set -eu

          for module in gpucc_glymur gxclkctl_kaanapali msm; do
            if [ -d "/sys/module/$module" ]; then
              echo "$module loaded before the ordered display service" >&2
              exit 1
            fi
          done

          modprobe -v gpucc-glymur
          modprobe -v gxclkctl-kaanapali
          modprobe -v msm
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };

      # The first installation intentionally exposes only the services that
      # configure their own access controls. Add a host firewall separately
      # after its policy has been chosen and tested.
      networking.firewall.enable = false;
    };
  };
}
