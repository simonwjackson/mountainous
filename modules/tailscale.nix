# Tailscale on every machine, joined before anyone logs in, and always under
# its own name.
#
# Two problems, two different fixes.
#
# JOINING UNATTENDED. services.tailscale.authKeyFile gives us
# tailscaled-autoconnect.service, which polls `tailscale status` and only runs
# `tailscale up` when the backend says NeedsLogin, NeedsMachineAuth or Stopped.
# It is therefore safe to leave enabled for ever; a machine that is already
# joined is left alone.
#
# The credential is an OAuth client secret, not an auth key. Auth keys cannot
# outlive 90 days -- "You cannot generate long-lived auth keys, because they
# expire after 90 days" -- which is useless for a handheld that spends three
# months in a drawer. An OAuth secret does not expire, and nodes it registers
# are tag-owned, so their keys do not expire either.
#
# Two parameters below are not optional. From the OAuth docs:
#
#   ephemeral:      register as an ephemeral node (defaults to TRUE)
#   preauthorized:  skip manual device approval (defaults to false)
#
# Take the defaults and every machine becomes ephemeral, which means it is
# removed from the tailnet whenever it goes offline. That is wrong for all of
# them and catastrophic for a server. Both are stated explicitly here.
#
# NAMING. Tailscale identifies a node by the key in
# /var/lib/tailscale/tailscaled.state, not by its hostname. Reinstall a machine
# and the control plane correctly sees a second, different device asking for a
# name that is taken, so it hands out <hostname>-1. There is no built-in
# deduplication; tailscale/tailscale#4371 has been open since 2022 asking for
# it.
#
# The suffix cannot be repaired afterwards. From the machine-names doc:
#
#   "If the conflicting machine's name is later changed, this machine will
#    still maintain the <hostname>-1 machine name."
#
# So the stale device has to go *before* the new one registers. That is what
# tailscale-claim-name does, and the whole reason it is safe to ship to every
# machine is the systemd condition on it:
#
#   ConditionPathExists=!/var/lib/tailscale/tailscaled.state
#
# The state file is the node identity. If it is present the machine already has
# one, will not register, cannot collide, and systemd skips the unit without
# running a line of it. No API call happens on an ordinary boot. The unit only
# ever executes on a machine that is about to introduce itself for the first
# time -- a fresh install, or a stick that has just been reflashed.
#
# Ordering is `before tailscaled.service`, not after, for the same reason: the
# window to clean up is before tailscaled exists to create that state file.
{
  nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.cairn.tailscale;
      inherit (lib) mkOption types mkIf;

      stateFile = "/var/lib/tailscale/tailscaled.state";

      claimName = pkgs.writeShellApplication {
        name = "tailscale-claim-name";
        runtimeInputs = [
          pkgs.curl
          pkgs.jq
          pkgs.coreutils
        ];
        text = ''
          api=https://api.tailscale.com/api/v2

          client_id=$(cat "$TS_CLIENT_ID_FILE")
          client_secret=$(cat "$TS_CLIENT_SECRET_FILE")

          # An access token lasts one hour, so it is minted per boot and never
          # stored. --retry covers a laptop whose wifi associates a moment
          # after network-online.target is reached.
          token=$(curl --silent --show-error --fail \
            --retry 5 --retry-delay 2 --retry-connrefused --max-time 30 \
            --data-urlencode "client_id=$client_id" \
            --data-urlencode "client_secret=$client_secret" \
            "$api/oauth/token" | jq -r '.access_token')

          if [ -z "$token" ] || [ "$token" = "null" ]; then
            echo "could not get an API token; leaving the tailnet untouched" >&2
            exit 1
          fi

          devices=$(curl --silent --show-error --fail \
            --retry 5 --retry-delay 2 --retry-connrefused --max-time 30 \
            --header "Authorization: Bearer $token" \
            "$api/tailnet/-/devices")

          # .name is the full MagicDNS name, so the machine name is its first
          # label. Strip any -N the control plane appended, then compare: that
          # sweeps up ghosts from earlier reinstalls as well as the one
          # currently holding the name.
          #
          # This assumes no machine in the fleet is deliberately named
          # <something>-<digits>. Nothing stops you doing that; it would make
          # this delete the wrong node.
          stale=$(printf '%s' "$devices" | jq -r --arg h "$TS_HOSTNAME" '
            .devices[]
            | select(((.name | split(".")[0]) | sub("-[0-9]+$"; "")) == $h)
            | .id')

          if [ -z "$stale" ]; then
            echo "no device is holding the name $TS_HOSTNAME"
            exit 0
          fi

          for id in $stale; do
            if curl --silent --show-error --fail --max-time 30 \
              --request DELETE \
              --header "Authorization: Bearer $token" \
              "$api/device/$id" >/dev/null; then
              echo "removed stale device $id holding $TS_HOSTNAME"
            else
              echo "could not remove stale device $id" >&2
            fi
          done
        '';
      };

      # OAuth registration is rejected without a tag, so an empty tag list is a
      # config error rather than a runtime surprise.
      autoJoins = cfg.oauthSecretFile != null;
      canClaim = autoJoins && cfg.oauthClientIdFile != null;
    in
    {
      options.cairn.tailscale = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Join this machine to the tailnet.";
        };

        tags = mkOption {
          type = types.listOf types.str;
          default = [ "tag:cairn" ];
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
            auth_keys scope. Until this is set the daemon runs but the machine
            does not join by itself.
          '';
        };

        oauthClientIdFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = ''
            File holding the OAuth client ID. Only the name-claiming step needs
            it, and that step additionally needs the devices:core scope to
            remove the device holding this machine's name.

            Leave null to join without claiming the name. A reinstall will then
            come back as <hostname>-1, permanently.
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
            assertion = !autoJoins || cfg.tags != [ ];
            message = "cairn.tailscale.tags must not be empty: registering with an OAuth secret requires --advertise-tags.";
          }
        ];

        services.tailscale = {
          enable = true;
          openFirewall = true;
          useRoutingFeatures = cfg.routingFeatures;

          authKeyFile = cfg.oauthSecretFile;

          # Neither default is what we want. See the header.
          authKeyParameters = {
            ephemeral = false;
            preauthorized = true;
          };

          extraUpFlags = [
            "--advertise-tags=${lib.concatStringsSep "," cfg.tags}"
            "--hostname=${config.networking.hostName}"
          ];
        };

        systemd.services.tailscale-claim-name = mkIf canClaim {
          description = "Free this machine's tailnet name before it registers";

          # Before tailscaled, because tailscaled is what creates the state
          # file this unit is conditioned on.
          before = [ "tailscaled.service" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          # The whole safety property. A machine with an identity never runs
          # this.
          unitConfig.ConditionPathExists = "!${stateFile}";

          serviceConfig = {
            Type = "oneshot";
            # tailscaled does not Require this unit, so a failure here delays
            # the join by at most this long and then lets it proceed. The cost
            # of failing is a -1 suffix, not a machine that never joins.
            TimeoutStartSec = "90s";
            ExecStart = lib.getExe claimName;
            Environment = [
              "TS_CLIENT_ID_FILE=${cfg.oauthClientIdFile}"
              "TS_CLIENT_SECRET_FILE=${cfg.oauthSecretFile}"
              "TS_HOSTNAME=${config.networking.hostName}"
            ];
          };
        };
      };
    };
}
