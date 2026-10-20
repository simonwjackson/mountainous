# The D-Bus notification owner and agent tools. The view is a separate module.
{ inputs, self, ... }:
let
  tools =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      sops.secrets.notify-agent-token = {
        sopsFile = ../secrets/notify/fleet.yaml;
        owner = "simon";
        mode = "0400";
      };
      sops.secrets.notify-button-token = {
        sopsFile = ../secrets/notify/fleet.yaml;
        owner = "simon";
        mode = "0400";
      };
      environment.systemPackages = [ self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync ];
      environment.variables = {
        NOTIFY_URL = lib.mkDefault config.mountainous.notifications.server;
        NOTIFY_TOKEN_FILE = lib.mkDefault config.sops.secrets.notify-agent-token.path;
        NOTIFY_BUTTON_TOKEN_FILE = lib.mkDefault config.sops.secrets.notify-button-token.path;
      };
    };
in
{
  perSystem = { pkgs, ... }: {
    packages.notify-sync =
      inputs.gomod2nix-rakku.legacyPackages.${pkgs.stdenv.hostPlatform.system}.buildGoApplication
        {
          pname = "notify-sync";
          version = "1.0.0";
          src = ../packages/notify-sync;
          modules = ../packages/notify-sync/gomod2nix.toml;
          go = pkgs.go;
          CGO_ENABLED = 0;
          nativeCheckInputs = [
            pkgs.dbus
            pkgs.libnotify
            pkgs.ntfy-sh
          ];
          preCheck = ''
            export NTFY_BIN=${pkgs.ntfy-sh}/bin/ntfy
            export NOTIFY_SEND=${pkgs.libnotify}/bin/notify-send
          '';
          postCheck = "go vet ./...";
          ldflags = [
            "-s"
            "-w"
          ];
          doCheck = true;
        };
    checks.notify-sync = self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync;
    checks.notify-sync-vm = import ../tests/notify-sync.nix {
      inherit pkgs;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync;
    };
    checks.notify-proxy =
      self.packages.${pkgs.stdenv.hostPlatform.system}.media-tsnet-proxy.overrideAttrs
        (old: {
          pname = "notify-proxy-check";
          postPatch = (old.postPatch or "") + ''
            cp ${../tests/notify-proxy.go} notify_stream_test.go
          '';
          nativeCheckInputs = (old.nativeCheckInputs or [ ]) ++ [ pkgs.ntfy-sh ];
          preCheck = (old.preCheck or "") + "export NTFY_BIN=${pkgs.ntfy-sh}/bin/ntfy";
        });
  };

  nixos.modules.base = { config, lib, ... }: {
    options.mountainous.notifications = {
      server = lib.mkOption {
        type = lib.types.str;
        default = "https://ntfy.hummingbird-lake.ts.net";
      };
      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/notify-desktop-token";
        description = "Runtime ntfy token file, owned by simon.";
      };
      localOnlyApps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Exact app_name values that must never leave this host.";
      };
    };
  };

  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [ tools ];
      sops.secrets.notify-desktop-token = {
        sopsFile = ../secrets/notify + "/${config.networking.hostName}.yaml";
        owner = "simon";
        mode = "0400";
      };
      mountainous.notifications.tokenFile = lib.mkDefault config.sops.secrets.notify-desktop-token.path;
      systemd.user.services.notifyd = {
        description = "Synced freedesktop notifications";
        partOf = [ "graphical-session.target" ];
        after = [ "graphical-session.target" ];
        wantedBy = [ "graphical-session.target" ];
        serviceConfig = {
          Type = "dbus";
          BusName = "org.freedesktop.Notifications";
          ExecStart = lib.concatStringsSep " " (
            [
              "${self.packages.${pkgs.stdenv.hostPlatform.system}.notify-sync}/bin/notifyd"
              "--host ${lib.escapeShellArg config.networking.hostName}"
              "--ntfy ${lib.escapeShellArg config.mountainous.notifications.server}"
              "--public-url ${lib.escapeShellArg config.mountainous.notifications.server}"
              "--token-file ${lib.escapeShellArg config.mountainous.notifications.tokenFile}"
              "--button-token-file ${config.sops.secrets.notify-button-token.path}"
            ]
            ++
              lib.optional (config.mountainous.notifications.localOnlyApps != [ ])
                "--local-only-apps ${lib.escapeShellArg (lib.concatStringsSep "," config.mountainous.notifications.localOnlyApps)}"
          );
          Restart = "on-failure";
          RestartSec = 2;
          Slice = "session.slice";
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
        };
      };
    };

  # Agent access is shared by desktop and headless layers. Base declares the
  # runtime credentials once; only these two layers put the tool on PATH.
  nixos.modules.server = {
    imports = [ tools ];
  };
}
