# Tailscale on every machine, joined whenever a network first appears, and
# never under a name with a number stuck on the end (<hostname>-1).
# See docs/decisions/tailscale.md for OAuth credentials, deduplication, and retry architecture.
{
  nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.mountainous.tailscale;
      inherit (lib) mkOption types mkIf;

      join = pkgs.writeShellApplication {
        name = "tailscale-join";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
          config.services.tailscale.package
        ];
        text = ''
          api=https://api.tailscale.com/api/v2

          # The hostname we insist on. Anything else is a failure to be undone.
          want="$TS_HOSTNAME"

          backend() { tailscale status --json 2>/dev/null | jq -r '.BackendState // "NoState"'; }
          # .DNSName is the full MagicDNS name, so the machine name is its
          # first label: "hiyori.tail1234.ts.net." -> "hiyori".
          myname() { tailscale status --json 2>/dev/null | jq -r '.Self.DNSName // ""' | cut -d. -f1; }

          state=$(backend)
          name=$(myname)

          # Already correct. This is the ordinary case on every boot after the
          # first, and it makes no API call at all.
          if [ "$state" = "Running" ] && [ "$name" = "$want" ]; then
            echo "already on the tailnet as $want"
            exit 0
          fi

          # Registered, but under a name the control plane renamed. The suffix
          # cannot be edited away, so the node has to go and come back.
          if [ "$state" = "Running" ] && [ -n "$name" ] && [ "$name" != "$want" ]; then
            echo "registered as '$name', wanted '$want' -- logging out to retake the name" >&2
            tailscale logout || true
          fi

          # From here on the network is required. Every failure below exits
          # non-zero so systemd tries again later; none of them registers the
          # machine under a name we did not ask for.
          client_id=$(cat "$TS_CLIENT_ID_FILE")
          client_secret=$(cat "$TS_CLIENT_SECRET_FILE")

          # An access token lasts one hour, so it is minted per attempt and
          # never stored. A short retry covers a link that is a few seconds
          # behind network-online.target; a long one would just duplicate what
          # systemd's Restart already does, less visibly.
          token=$(curl --silent --show-error --fail \
            --retry 3 --retry-delay 2 --retry-connrefused --max-time 30 \
            --data-urlencode "client_id=$client_id" \
            --data-urlencode "client_secret=$client_secret" \
            "$api/oauth/token" 2>/dev/null | jq -r '.access_token // ""') || true

          if [ -z "$token" ] || [ "$token" = "null" ]; then
            echo "no route to the tailscale API yet; will try again" >&2
            exit 1
          fi

          devices=$(curl --silent --show-error --fail --max-time 30 \
            --header "Authorization: Bearer $token" \
            "$api/tailnet/-/devices" 2>/dev/null) || true

          if [ -z "$devices" ]; then
            echo "could not list devices; will try again" >&2
            exit 1
          fi

          # Match the wanted name and any -N the control plane appended, so
          # ghosts from earlier reinstalls are swept up too.
          #
          # This assumes no machine is deliberately named <something>-<digits>.
          # Nothing stops you doing that; it would delete the wrong node.
          stale=$(printf '%s' "$devices" | jq -r --arg h "$want" '
            .devices[]
            | select(((.name | split(".")[0]) | sub("-[0-9]+$"; "")) == $h)
            | .id')

          for id in $stale; do
            if curl --silent --show-error --fail --max-time 30 \
              --request DELETE \
              --header "Authorization: Bearer $token" \
              "$api/device/$id" >/dev/null 2>&1; then
              echo "removed device $id holding $want"
            else
              # Refuse rather than register into a known collision.
              echo "could not remove device $id; not registering" >&2
              exit 1
            fi
          done

          # Confirm the name is actually free before using it. The delete
          # returning 200 is not the same as the control plane having released
          # the name, and this is the whole point of the unit.
          remaining=$(curl --silent --show-error --fail --max-time 30 \
            --header "Authorization: Bearer $token" \
            "$api/tailnet/-/devices" 2>/dev/null \
            | jq -r --arg h "$want" '
                [ .devices[]
                  | select(((.name | split(".")[0]) | sub("-[0-9]+$"; "")) == $h)
                ] | length') || true

          if [ "''${remaining:-1}" != "0" ]; then
            echo "$want is still taken after the delete; not registering" >&2
            exit 1
          fi

          echo "$want is free; registering"
          tailscale up \
            --auth-key="$client_secret?ephemeral=false&preauthorized=true" \
            --advertise-tags="$TS_TAGS" \
            --hostname="$want"

          # Verify the outcome instead of trusting the exit code. tailscale up
          # can succeed and still leave the node named hiyori-1.
          for _ in $(seq 1 20); do
            [ "$(backend)" = "Running" ] && break
            sleep 1
          done

          got=$(myname)
          if [ "$(backend)" != "Running" ]; then
            echo "up finished but the backend is $(backend); will try again" >&2
            exit 1
          fi
          if [ "$got" != "$want" ]; then
            echo "registered as '$got', not '$want' -- undoing and retrying" >&2
            tailscale logout || true
            exit 1
          fi

          echo "joined as $want"
        '';
      };

      canJoin = cfg.oauthSecretFile != null && cfg.oauthClientIdFile != null;
    in
    {
      options.mountainous.tailscale = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Join this machine to the tailnet.";
        };

        tags = mkOption {
          type = types.listOf types.str;
          default = [ "tag:mountainous" ];
          description = ''
            Tags to claim at registration. Required when registering with an
            OAuth secret, and the OAuth client must own every tag listed.
            Tagged devices also have key expiry disabled.
          '';
        };

        oauthSecretFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          example = "config.sops.secrets.tailscale-oauth-secret.path";
          description = ''
            File holding the OAuth client secret (tskey-client-...). Needs the
            auth_keys scope.
          '';
        };

        oauthClientIdFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            File holding the OAuth client ID. Needs the devices:core scope, to
            remove whatever is holding this machine's name.

            Required, not optional. Registering without first freeing the name
            is how a machine ends up called <hostname>-1 for ever, and that
            cannot be repaired afterwards. With no client ID the machine stays
            off the tailnet, which is recoverable.
          '';
        };

        routingFeatures = mkOption {
          type = types.enum [
            "none"
            "client"
            "server"
            "both"
          ];
          default = "client";
          description = ''
            "client" is enough to use an exit node. A machine that offers one,
            or advertises subnet routes, needs "server" or "both".
          '';
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = !canJoin || cfg.tags != [ ];
            message = "mountainous.tailscale.tags must not be empty: registering with an OAuth secret requires --advertise-tags.";
          }
          {
            assertion = (cfg.oauthSecretFile == null) == (cfg.oauthClientIdFile == null);
            message = "mountainous.tailscale needs both oauthSecretFile and oauthClientIdFile, or neither. The client ID is what frees this machine's name before it registers; without it a reinstall becomes <hostname>-1 permanently.";
          }
        ];

        services.tailscale = {
          enable = true;
          openFirewall = true;
          useRoutingFeatures = cfg.routingFeatures;

          # Deliberately not set. authKeyFile makes the upstream module
          # generate tailscaled-autoconnect, which runs `tailscale up` as soon
          # as it can -- with no idea whether the name is free. That unit and
          # this one would race, and the race is exactly the bug being fixed.
          # Registration happens here or not at all.
          authKeyFile = null;
        };

        systemd.services.tailscale-join = mkIf canJoin {
          description = "Join the tailnet, under this machine's own name";

          # After tailscaled, because this asks the running daemon what state
          # it is in. network-online.target is a hint, not a guarantee: it
          # means an interface came up, not that anything resolves. The retry
          # below is what actually copes with that.
          after = [
            "tailscaled.service"
            "network-online.target"
          ];
          wants = [ "network-online.target" ];
          requires = [ "tailscaled.service" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.getExe join;

            # Keep trying. A network may be three minutes away, or behind a
            # captive portal, or ten boots away. Every failure path in the
            # script leaves the machine unregistered rather than misnamed, so
            # retrying for ever is safe.
            Restart = "on-failure";
            RestartSec = "30s";

            Environment = [
              "TS_CLIENT_ID_FILE=${cfg.oauthClientIdFile}"
              "TS_CLIENT_SECRET_FILE=${cfg.oauthSecretFile}"
              "TS_HOSTNAME=${config.networking.hostName}"
              "TS_TAGS=${lib.concatStringsSep "," cfg.tags}"
            ];
          };

          # systemd gives up after 5 starts in 10s by default. That would stop
          # the retry loop within the first minute, which is the one thing
          # this unit must not do.
          unitConfig.StartLimitIntervalSec = 0;
        };
      };
    };
}
