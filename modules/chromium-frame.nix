# Normal Chromium windows keep tabs, but delegate the outer frame to Hyprland.
# initialPrefs is a first-run seed, not a policy. Existing profiles are migrated
# before the compositor can restore apps. Locked user-data roots are deferred.
{ self, ... }:
let
  initialPrefs = {
    browser.custom_chrome_frame = false;
    # ui::SystemTheme::kGtk. GTK supplies paint/font, not tab geometry.
    extensions.theme.system_theme = 1;
  };
  command =
    pkgs:
    pkgs.writeShellApplication {
      name = "chromium-frame";
      runtimeInputs = [ pkgs.python3 ];
      text = ''
        exec python3 ${../scripts/chromium-frame.py}
      '';
    };
in
{
  perSystem = { pkgs, system, ... }: {
    packages.chromium-frame = command pkgs;
    checks.chromium-frame =
      let
        desktop = self.nixosConfigurations.myoko.config;
      in
      assert desktop.programs.chromium.initialPrefs.browser.custom_chrome_frame == false;
      assert desktop.programs.chromium.initialPrefs.extensions.theme.system_theme == 1;
      assert desktop.systemd.user.services.chromium-frame.serviceConfig.Type == "oneshot";
      pkgs.runCommand "chromium-frame"
        {
          nativeBuildInputs = [ pkgs.python3 ];
          CLI = "${self.packages.${system}.chromium-frame}/bin/chromium-frame";
          FRAME_SCRIPT = ../scripts/chromium-frame.py;
        }
        ''
          python3 ${../tests/test_chromium_frame.py}
          export HOME="$TMPDIR/private-home"
          export XDG_CONFIG_HOME="$HOME/config"
          mkdir -p "$XDG_CONFIG_HOME/chromium/Default"
          printf '%s' '{"browser":{"custom_chrome_frame":true},"keep":7}' > "$XDG_CONFIG_HOME/chromium/Default/Preferences"
          "$CLI"
          python3 -c 'import json,os; p=json.load(open(os.environ["XDG_CONFIG_HOME"]+"/chromium/Default/Preferences")); assert p == {"browser":{"custom_chrome_frame":False},"keep":7}'
          touch "$out"
        '';
  };

  nixos.modules.desktop = { pkgs, lib, ... }: {
    programs.chromium = {
      enable = lib.mkDefault true;
      initialPrefs = lib.mkDefault initialPrefs;
    };
    systemd.user.services.chromium-frame = {
      description = "Request system frames in stopped Chromium profiles";
      # start-mountainous waits for this before starting Hyprland/session restore.
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${command pkgs}/bin/chromium-frame";
        TimeoutStartSec = 15;
      };
    };
  };
}
