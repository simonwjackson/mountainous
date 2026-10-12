# A Moonlight client as a second screen, stacked below the laptop panel.
#
# Sunshine streams one Hyprland monitor that exists only while a client is
# connected. modules/second-screen.py creates it at the client's size, under
# the panel, and removes it once the client has gone. Hyprland then moves its
# pages, windows and all, back onto the panel. See
# docs/decisions/second-screen.md.
#
# Tuned for desktop work, not games: the client picks resolution, frame rate
# and bitrate, so the settings here only choose the capture path and the
# encoder, and keep the laptop's sound on the laptop.
{ inputs, ... }:
{
  nixos.modules.desktop =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.features.sunshine;

      # Sunshine follows its newest release, apart from the system pin.
      # 2026.914.233613 carries a high-severity Linux fix
      # (GHSA-fp6g-27w5-489j); the locked nixpkgs had 2026.516.143833.
      upstream = import inputs.nixpkgs-sunshine {
        system = pkgs.stdenv.hostPlatform.system;
      };

      second-screen = pkgs.writeShellApplication {
        name = "mountainous-second-screen";
        runtimeInputs = [
          pkgs.python3
          config.programs.hyprland.package # hyprctl
        ];
        text = ''
          exec python3 ${./second-screen.py} "$@"
        '';
      };
      run = command: "${lib.getExe second-screen} ${command}";

      # Sunshine's ports, from its configuration docs (`port`). The base is
      # 47989; the module opens the same set on every interface.
      base = config.services.sunshine.settings.port;
      tcpPorts = map (offset: base + offset) [ (-5) 0 1 21 ];
      udpPorts = map (offset: base + offset) [ 9 10 11 13 21 ];
    in
    {
      options.mountainous.features.sunshine = {
        enable = lib.mkEnableOption "Sunshine, streaming a second screen to a Moonlight client";

        user = lib.mkOption {
          type = lib.types.str;
          default = "simon";
          description = "User whose Hyprland session gains the second screen.";
        };

        grace = lib.mkOption {
          type = lib.types.ints.positive;
          default = 15;
          description = ''
            Seconds a client may be gone before its screen is removed. A
            client back inside this time finds its screen as it left it.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        services.sunshine = {
          enable = true;
          package = upstream.sunshine;
          # wlr capture, below, needs no CAP_SYS_ADMIN. KMS capture would,
          # and it cannot see a headless output at all.
          capSysAdmin = false;
          # Tailscale only; see the firewall below.
          openFirewall = false;

          settings = {
            sunshine_name = config.networking.hostName;

            # Hyprland's headless outputs exist only for compositor capture.
            # Sunshine's docs: "It is possible to capture virtual displays in
            # e.g. Hyprland using this method."
            capture = "wlr";
            output_name = "SUNSHINE"; # modules/second-screen.py OUTPUT

            # Intel Iris Xe (Raptor Lake-P, i915), the only GPU. vainfo shows
            # H.264 and HEVC encode, no AV1. Sunshine's VA-API encoder has no
            # 4:4:4 path on Linux (src/video.cpp: no YUV444_SUPPORT flag), so
            # the stream is 4:2:0 whatever the client asks.
            encoder = "vaapi";
            adapter_name = "/dev/dri/renderD128";

            # Sound stays on the laptop. Sunshine's docs: "Disabling this can
            # be useful for streaming headless displays as second monitors."
            # Enabled, it would make its own sink the default and mute the
            # laptop for as long as the tablet is attached.
            stream_audio = "disabled";
          };

          applications.apps = [
            {
              name = "Second screen";
              prep-cmd = [
                {
                  do = run "attach";
                  undo = run "detach";
                }
              ];
              # Sunshine counts the app as running while this lives. Without
              # it, a client that leaves without quitting would leave the
              # screen, and its windows, attached and out of sight.
              cmd = run "hold";
              auto-detach = "false";
              exit-timeout = 5;
            }
          ];
        };

        systemd.user.services.sunshine = {
          # Sunshine passes its own environment to the app's commands.
          environment.MOUNTAINOUS_SECOND_SCREEN_GRACE = toString cfg.grace;
          unitConfig.ConditionUser = cfg.user;
          serviceConfig = {
            # A Sunshine that crashed mid-stream ran no "undo". Clear any
            # output it left before starting, and after stopping. The leading
            # "-" keeps a failed cleanup from blocking Sunshine itself.
            ExecStartPre = "-${run "detach"}";
            ExecStopPost = "-${run "detach"}";
            # Sunshine exits 0 even after a fatal error, so on-failure never
            # retries it. Seen on Myoko on 2026-10-12: one start died with
            # "Couldn't start Configuration HTTPS server on port [47990]:
            # Address already in use" while nothing held the port; the next
            # start worked. The module's start limit (5 in 500 s) still
            # applies.
            Restart = lib.mkForce "always";
          };
        };

        # The module enables Avahi so LAN clients can discover the host. The
        # ports are closed on the LAN, so a discovered address would only
        # fail. Clients add the host by its tailnet name instead.
        services.avahi.enable = lib.mkOverride 999 false;

        networking.firewall.interfaces.tailscale0 = {
          allowedTCPPorts = tcpPorts;
          allowedUDPPorts = udpPorts;
        };

        environment.systemPackages = [ second-screen ];

        hjem.users.${cfg.user}.files.".config/hypr/second-screen.lua".source =
          ./hyprland/second-screen.lua;
      };
    };
}
