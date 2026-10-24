# Approved Platinum lock: static device-pixel dialog art, live hyprlock field.
{ self, ... }:
let
  lockArt =
    pkgs: host: user:
    pkgs.runCommand "mountainous-lock-art"
      {
        nativeBuildInputs = [
          pkgs.python3
          pkgs.librsvg
        ];
        FONTCONFIG_FILE = pkgs.makeFontsConf {
          fontDirectories = [ self.packages.${pkgs.stdenv.hostPlatform.system}.chicagoflf ];
          impureFontDirectories = [ ];
          # The approved mock disables hinting in the pre-rendered text.
          includes = [
            (pkgs.writeText "lock-font-rendering.conf" ''
              <fontconfig><match target="font"><edit name="hinting" mode="assign"><bool>false</bool></edit></match></fontconfig>
            '')
          ];
        };
      }
      ''
        export HOME="$TMPDIR"
        export XDG_CACHE_HOME="$TMPDIR/cache"
        python3 ${./lock}/generate.py "$out" --host ${pkgs.lib.escapeShellArg host} --user ${pkgs.lib.escapeShellArg user}
      '';
  lockCommand =
    pkgs: hyprland: hyprlock: art:
    pkgs.writeShellApplication {
      name = "mountainous-lock";
      runtimeInputs = [
        pkgs.python3
        pkgs.util-linux
        hyprland
        hyprlock
      ];
      text =
        builtins.replaceStrings
          [ "@art@" "@configure@" "@fallback@" ]
          [ "${art}" "${./lock}/configure.py" "${./lock/hyprlock-fallback.conf}" ]
          (builtins.readFile ./lock/mountainous-lock.sh);
    };
  dpms =
    pkgs: hyprland: action:
    pkgs.writeShellApplication {
      name = "mountainous-dpms-${action}";
      runtimeInputs = [ hyprland ];
      text = ''
        # Select this session, never another compositor's instance 0.
        hyprctl --instance "''${HYPRLAND_INSTANCE_SIGNATURE:?missing session instance}" dispatch 'hl.dsp.dpms({ action = "${action}" })'
      '';
    };
in
{
  perSystem =
    { pkgs, ... }:
    let
      art = lockArt pkgs "Myoko" "simon";
    in
    {
      packages.mountainous-lock-art = art;
      packages.mountainous-lock = lockCommand pkgs pkgs.hyprland pkgs.hyprlock art;
      checks.lock-config =
        pkgs.runCommand "lock-config"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.bash
              pkgs.util-linux
            ];
          }
          ''
            python3 ${../tests/test_lock.py} ${./lock}
            touch $out
          '';
      checks.lock-art =
        pkgs.runCommand "lock-art"
          {
            nativeBuildInputs = [ pkgs.python3 ];
          }
          ''
            python3 ${../tests/test_lock_art.py} ${./lock} ${art}
            touch $out
          '';
      checks.lock-policy =
        let
          c = self.nixosConfigurations.myoko.config;
          unit = c.systemd.user.services.hypridle.serviceConfig.ExecStart;
          policy = c.system.build.mountainousHypridleConfig;
          screenOff = c.systemd.user.services.mountainous-lock-screen-off.serviceConfig;
          valid =
            c.programs.hyprlock.enable
            && c.services.hypridle.enable
            && c.security.pam.services ? hyprlock
            && pkgs.lib.hasInfix "pam_unix.so" c.security.pam.services.hyprlock.text
            && !(c.systemd.user.services ? oled-idle)
            && screenOff.Type == "oneshot"
            && screenOff.RemainAfterExit
            && pkgs.lib.hasSuffix "/bin/sleep 30" screenOff.ExecStart
            && pkgs.lib.hasInfix " -c ${policy}" unit;
        in
        assert valid;
        pkgs.runCommand "lock-policy" { nativeBuildInputs = [ pkgs.python3 ]; } ''
          python3 ${../tests/test_lock_policy.py} ${policy}
          touch $out
        '';
    };

  nixos.modules.desktop =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      host = config.networking.hostName;
      hostLabel =
        (lib.toUpper (builtins.substring 0 1 host))
        + (builtins.substring 1 (builtins.stringLength host) host);
      art = lockArt pkgs hostLabel "simon";
      lock = lockCommand pkgs config.programs.hyprland.package config.programs.hyprlock.package art;
      dpmsOn = "${dpms pkgs config.programs.hyprland.package "on"}/bin/mountainous-dpms-on";
      dpmsOff = "${dpms pkgs config.programs.hyprland.package "off"}/bin/mountainous-dpms-off";
      onBattery = pkgs.writeShellScript "mountainous-on-battery" ''
        ${pkgs.gnugrep}/bin/grep -qsx Discharging /sys/class/power_supply/BAT*/status
      '';
      policy = pkgs.replaceVars ./lock/hypridle.conf {
        lock = "${lock}/bin/mountainous-lock";
        inherit dpmsOn dpmsOff onBattery;
      };
    in
    {
      programs.hyprlock.enable = lib.mkDefault true;
      services.hypridle.enable = lib.mkDefault true;
      environment.systemPackages = [ lock ];
      system.build.mountainousLock = lock;
      system.build.mountainousLockArt = art;
      system.build.mountainousHypridleConfig = policy;
      systemd.user.services.hypridle = lib.mkIf config.services.hypridle.enable {
        # Upstream exposes enable/package only. -c prevents a stale home config
        # from shadowing the policy. The NixOS module installs the upstream unit.
        serviceConfig.ExecStart = lib.mkDefault "${config.services.hypridle.package}/bin/hypridle -c ${policy}";
        path = [
          pkgs.systemd
          pkgs.procps
        ];
        serviceConfig.Restart = lib.mkDefault "on-failure";
      };
      # oled-idle's idle blank/resume becomes lock + delayed blank/resume.
      # Its immediate pre-sleep DPMS-off is superseded by lock-before-sleep
      # with inhibit_sleep=3; if suspend is delayed, this timer still blanks.
      systemd.user.services.mountainous-lock-screen-off = {
        description = "Blank displays thirty seconds after a confirmed session lock";
        partOf = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.coreutils}/bin/sleep 30";
          ExecStartPost = dpmsOff;
          # is-active stays false during sleep, gating the 30 s idle listener.
          TimeoutStartSec = 40;
        };
      };
    };
}
