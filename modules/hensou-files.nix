# Hensou Files on the desktop (Hensou docs/design/files.md, "First-release
# decisions"): the resident `hensou-files --daemon` user service, the
# default handler for folders, and the udisks2 rights it needs to mount,
# eject and power off removable media. The shell side (the Start and Apple
# menu entries, Super+E, the tray, Show Desktop) is in modules/quickshell
# and modules/hyprland/hyprland.lua; the menu entries show only where the
# hensou-files desktop entry is installed, which is this layer.
#
# The package comes from the hensou flake input. Until the pinned Hensou
# has a `hensou-files` output, the layer installs nothing but the polkit
# rule, so every host still evaluates before and after the repin.
{ self, inputs, ... }:
let
  # The actions the person at the machine may take on removable media
  # without a password, even from a user service such as Files (no login
  # session of its own: polkit judges it by the user's display session).
  # Internal disks use the *-system actions, which stay at udisks2's
  # defaults (an administrator's password).
  udisksRule = ''
    // Hensou Files (modules/hensou-files.nix): mount, eject and power off
    // removable media for the active local user.
    polkit.addRule(function (action, subject) {
      var removable = [
        "org.freedesktop.udisks2.filesystem-mount",
        "org.freedesktop.udisks2.eject-media",
        "org.freedesktop.udisks2.power-off-drive"
      ];
      if (removable.indexOf(action.id) < 0) return polkit.Result.NOT_HANDLED;
      if (subject.local && subject.active && subject.isInGroup("users")) return polkit.Result.YES;
      return polkit.Result.NOT_HANDLED;
    });
  '';
in
{
  nixos.modules.files =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.files;
      hensou = inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system} or { };
    in
    {
      options.mountainous.features.files = {
        enable = lib.mkOption {
          type = lib.types.bool;
          # On wherever the pinned Hensou has the package.
          default = hensou ? hensou-files;
          description = "Hensou Files: the resident service, the folder handler and its desktop entry.";
        };
        package = lib.mkOption {
          type = lib.types.nullOr lib.types.package;
          default = hensou.hensou-files or null;
          description = "The hensou-files package (Hensou flake output).";
        };
      };

      config = lib.mkMerge [
        {
          services.udisks2.enable = lib.mkDefault true;
          security.polkit.enable = lib.mkDefault true;
          security.polkit.extraConfig = udisksRule;
        }
        (lib.mkIf cfg.enable {
          assertions = [
            {
              assertion = cfg.package != null;
              message = "mountainous.features.files: the pinned hensou input has no hensou-files package.";
            }
          ];
        })
        (lib.mkIf (cfg.enable && cfg.package != null) {
          # The binary (Super+E) and hensou-files.desktop (MimeType=inode/directory).
          environment.systemPackages = [ cfg.package ];
          xdg.mime.enable = true;
          xdg.mime.defaultApplications."inode/directory" = "hensou-files.desktop";

          # Resident from login: transfers, volumes (mount on insert) and the
          # desktop provider on $XDG_RUNTIME_DIR/hensou/desktop.sock. A later
          # `hensou-files <path>` hands its request to it and exits.
          systemd.user.services.hensou-files = {
            description = "Hensou Files (resident)";
            partOf = [ "graphical-session.target" ];
            after = [ "graphical-session.target" ];
            wantedBy = [ "graphical-session.target" ];
            # Wayland and Hyprland variables come from the user manager
            # (modules/hyprland.nix); ssh and handlers from the system path.
            environment.DBUS_SESSION_BUS_ADDRESS = "unix:path=%t/bus";
            path = [ "/run/current-system/sw" ];
            serviceConfig = {
              ExecStart = "${lib.getExe' cfg.package "hensou-files"} --daemon";
              Restart = "on-failure";
              RestartSec = 2;
              Slice = "session.slice";
            };
          };
        })
      ];
    };

  perSystem =
    { pkgs, lib, ... }:
    let
      myoko = self.nixosConfigurations.myoko.config;
      hiyori = self.nixosConfigurations.hiyori.config;
      files = myoko.mountainous.features.files;
      unit = myoko.systemd.user.services.hensou-files or null;
      quickshell = ./quickshell;
    in
    {
      # Files' shell and Nix wiring: the evaluated Myoko (the service, the
      # folder handler and the polkit rule follow the hensou-files output),
      # the polkit rule run against fake subjects, the keys, and the pure
      # models of the tray host, Show Desktop and the menus.
      checks.files-chrome =
        assert lib.hasInfix "org.freedesktop.udisks2.filesystem-mount" myoko.security.polkit.extraConfig;
        assert !(lib.hasInfix "filesystem-mount-system" myoko.security.polkit.extraConfig);
        assert myoko.services.udisks2.enable;
        # Myoko only: Hiyori does not carry the files layer.
        assert !(hiyori.mountainous.features ? files);
        assert
          files.enable
          == (inputs.hensou.packages.${pkgs.stdenv.hostPlatform.system} ? hensou-files);
        assert
          files.enable
          -> (
            unit != null
            && lib.hasSuffix "/bin/hensou-files --daemon" unit.serviceConfig.ExecStart
            && builtins.elem "graphical-session.target" unit.wantedBy
            && builtins.elem "graphical-session.target" unit.partOf
            && myoko.xdg.mime.defaultApplications."inode/directory" == "hensou-files.desktop"
            && builtins.elem files.package myoko.environment.systemPackages
          );
        assert !files.enable -> (unit == null && !(myoko.xdg.mime.defaultApplications ? "inode/directory"));
        pkgs.runCommand "files-chrome"
          {
            nativeBuildInputs = [
              pkgs.nodejs
              pkgs.lua
            ];
            RULE = pkgs.writeText "udisks-rule.js" udisksRule;
            FILES_ENABLED = lib.boolToString files.enable;
          }
          ''
            node ${./hensou-files-polkit.test.js} "$RULE"
            lua ${./hyprland/files-keys.test.lua} ${./hyprland/hyprland.lua}
            node ${quickshell}/sni-tray.test.js ${quickshell}/sni-tray.js ${quickshell}/themes/shared/tray-lettermark.js
            node ${quickshell}/show-desktop.test.js ${quickshell}/show-desktop.js
            node ${quickshell}/themes/platinum/menu-models.test.js ${quickshell}/themes/platinum/menu-models.js
            node ${quickshell}/themes/win98/models.test.js ${quickshell}/themes/win98/tray-model.js ${quickshell}/themes/win98/start-model.js
            node ${quickshell}/themes/win98/task-model.test.js ${quickshell}/themes/win98/task-model.js \
              ${quickshell}/themes/win98/session-model.js ${quickshell}/page-names.js
            node ${quickshell}/themes/win98/taskbar-plan.test.js ${quickshell}/themes/win98/taskbar-plan.js
            node ${quickshell}/bar-plan.test.js ${quickshell}/bar-plan.js ${quickshell}/bar-fixtures.json ${quickshell}/PlatinumTopBar.qml
            echo "files layer enabled: $FILES_ENABLED"
            touch $out
          '';
    };
}
