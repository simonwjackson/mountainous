# Join fresh machines when the network appears. Preserve saved identities
# rather than reclaim names automatically.
# See docs/decisions/tailscale.md for OAuth credentials and retry architecture.
{ self, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      # Exercise a real service ExecStart on the check runner's architecture.
      host = if pkgs.stdenv.hostPlatform.isAarch64 then "fuji" else "myoko";
      join =
        self.nixosConfigurations.${host}.config.systemd.services.tailscale-join.serviceConfig.ExecStart;
    in
    {
      checks.tailscale-join =
        pkgs.runCommand "tailscale-join-tests"
          {
            nativeBuildInputs = [
              pkgs.bash
              pkgs.jq
              pkgs.coreutils
              pkgs.gnugrep
            ];
          }
          ''
            bash ${../scripts/test-tailscale-join} ${join}
            touch $out
          '';
    };

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
          pkgs.gnused
          config.services.tailscale.package
        ];
        text = ''
          api=https://api.tailscale.com/api/v2

          want="$TS_HOSTNAME"

          # Each decision uses one daemon snapshot. NoState/Starting can expose
          # incomplete or changing keys while a saved identity is restored.
          read_status() {
            status=$(tailscale status --json 2>/dev/null) || {
              echo "cannot read tailscaled status; will retry" >&2
              return 1
            }
            if ! printf '%s' "$status" | jq -e '
              type == "object" and (.BackendState | type == "string")
            ' >/dev/null 2>&1; then
              echo "invalid tailscaled status; will retry" >&2
              return 1
            fi
          }
          fresh_login() {
            printf '%s' "$status" | jq -e '
              .BackendState == "NeedsLogin" and .Self == null
            ' >/dev/null 2>&1
          }

          read_status
          state=$(printf '%s' "$status" | jq -r '.BackendState')
          if [ "$state" = "Running" ] && printf '%s' "$status" | jq -e --arg h "$want" '
            (.Self.DNSName | type == "string") and
            (.Self.DNSName | split(".")[0] == $h) and
            (.Self.PublicKey | type == "string" and length > 0)
          ' >/dev/null 2>&1; then
            # Do not call up or depend on OAuth/API availability for a valid
            # saved node. Inherited preferences and its address stay intact.
            echo "already on the tailnet as $want"
            exit 0
          fi
          if ! fresh_login; then
            echo "tailscaled is not an identity-free NeedsLogin node; preserving state and retrying" >&2
            exit 1
          fi

          # Only a fresh login needs the network and credentials. Failures
          # retry through systemd; no path deletes devices or logs out.
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
            "$api/oauth/token" 2>/dev/null \
            | jq -er '.access_token | select(type == "string" and length > 0)' 2>/dev/null) || true

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

          # The API is only a collision guard, never evidence that a device
          # is stale. Even a different early key cannot justify deleting it.
          if ! printf '%s' "$devices" | jq -e '
            (.devices | type == "array") and
            all(.devices[]; (.name | type == "string" and length > 0))
          ' >/dev/null 2>&1; then
            echo "invalid device list; not registering" >&2
            exit 1
          fi
          collisions=$(printf '%s' "$devices" | jq -r --arg h "$want" '
            [ .devices[]
              | select(((.name | split(".")[0]) | sub("-[0-9]+$"; "")) == $h)
            ] | length')
          if [ "$collisions" != 0 ]; then
            echo "$want is already taken; operator review required, not registering" >&2
            exit 1
          fi

          # API calls take time. Do not up if a saved identity has appeared
          # since the initial snapshot. The next systemd attempt can use it.
          read_status
          if ! fresh_login; then
            echo "tailscaled changed during the join check; preserving state and retrying" >&2
            exit 1
          fi

          echo "$want is free; registering"
          # up requires existing non-default preferences to be repeated.
          # Never use --reset: it would discard operator-owned settings.
          prefs=$(tailscale debug prefs)
          if ! printf '%s' "$prefs" | jq -e '
            type == "object" and
            (.RunSSH == null or (.RunSSH | type == "boolean")) and
            (.OperatorUser == null or (.OperatorUser | type == "string"))
          ' >/dev/null 2>&1; then
            echo "invalid saved preferences; not registering" >&2
            exit 1
          fi
          ssh_enabled=$(printf '%s' "$prefs" | jq -r '.RunSSH // false | tostring')
          operator=$(printf '%s' "$prefs" | jq -r '.OperatorUser // ""')
          netfilter=$(printf '%s' "$prefs" | jq -r '.NetfilterMode // 2')
          case "$netfilter" in
            0) netfilter=off ;;
            1) netfilter=nodivert ;;
            2) netfilter=on ;;
            *) echo "unknown netfilter preference; not registering" >&2; exit 1 ;;
          esac
          up_log=$(mktemp)
          trap 'rm -f "$up_log"' EXIT
          if tailscale up \
            --auth-key="$client_secret?ephemeral=false&preauthorized=true" \
            --advertise-tags="$TS_TAGS" \
            --hostname="$want" \
            --ssh="$ssh_enabled" \
            --netfilter-mode="$netfilter" \
            --operator="$operator" >"$up_log" 2>&1; then
            sed -E 's/tskey-[^[:space:]]+/<REDACTED>/g' "$up_log"
          else
            sed -E 's/tskey-[^[:space:]]+/<REDACTED>/g' "$up_log" >&2
            exit 1
          fi

          # Verify from coherent snapshots, without undoing an identity if
          # the control plane assigned an unexpected name during a race.
          for _ in $(seq 1 20); do
            read_status
            state=$(printf '%s' "$status" | jq -r '.BackendState')
            [ "$state" = "Running" ] && break
            sleep 1
          done
          if [ "$state" != "Running" ]; then
            echo "up finished but the backend is not Running; will retry" >&2
            exit 1
          fi
          got=$(printf '%s' "$status" | jq -r '.Self.DNSName // "" | split(".")[0]')
          if [ "$got" != "$want" ]; then
            echo "registered under an unexpected name; preserving identity for operator review" >&2
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
            File holding the OAuth client ID. Needs read access to devices
            (devices:core) to check for name collisions before a fresh join.
            Existing devices are never deleted automatically. A collision
            needs operator review before this machine can register.
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
            message = "mountainous.tailscale needs both oauthSecretFile and oauthClientIdFile, or neither. The client ID checks for name collisions before a fresh registration.";
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

        # Tailscale's own "online" synchronization point, defined as upstream
        # ships it (cmd/tailscaled/tailscale-online.target and
        # tailscale-wait-online.service). nixpkgs installs only
        # tailscaled.service. network-online.target means the LAN is up, not
        # that the tailnet is reachable, so tailnet clients order after this.
        systemd.targets.tailscale-online = {
          description = "Tailscale is online";
          requires = [ "tailscale-wait-online.service" ];
          after = [ "tailscale-wait-online.service" ];
        };
        systemd.services.tailscale-wait-online = {
          description = "Wait for Tailscale to be online";
          after = [ "tailscaled.service" ];
          requires = [ "tailscaled.service" ];
          wantedBy = [ "tailscale-online.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${config.services.tailscale.package}/bin/tailscale wait";
            RemainAfterExit = true;
            # Upstream has no limit. Oneshot units wait forever by default,
            # which would hold every dependent unit, and boot, on a
            # tailnet that never comes up.
            TimeoutStartSec = "3min";
          };
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
            # script preserves existing identities. Collisions need operator
            # review; retrying never deletes a device or logs out.
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
