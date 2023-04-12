{ config, pkgs, lib, ... }:

let
  getOpenPRsScript = pkgs.writeShellScriptBin "get-open-prs" ''
    set -euo pipefail

    GITHUB_TOKEN=${builtins.getEnv "GITHUB_TOKEN"}
    GITHUB_USER=${builtins.getEnv "GITHUB_USER"} 
    XDG_CACHE_HOME=${config.xdg.cacheHome}

    output_file="''${XDG_CACHE_HOME}/github/open-prs"
    mkdir -p "''${XDG_CACHE_HOME}/github"
    touch "$output_file"

    query='{
      "query": "query {
        search(
          query: \"review-requested:''${GITHUB_USER} is:pr is:open\",
          type: ISSUE,
          first: 100
        ) {
          issueCount
        }
      }"
    }'

    count=$(
      curl -s \
        -H "Authorization: bearer ''${GITHUB_TOKEN}" \
        -X POST \
        -d "''${query}" \
        https://api.github.com/graphql \
      | jq '.data.search.issueCount'
    )

    ${pkgs.coreutils}/bin/echo ''${count} > "''${output_file}"

    # Send signal to AwesomeWM
    #awesome-client "awesome.emit_signal('open_prs_updated')"
  '';

in
{
  systemd.user.startServices = true;

  systemd.user.services.get-open-prs = {
    Unit = {
      description = "Get the number of open Github PRs to be reviewed";
    };
    Service = {
      ExecStart = "${getOpenPRsScript}/bin/get-open-prs";
      Type = "oneshot";
    };
  };

  systemd.user.timers."get-open-prs" = {
    Unit = {
      description = "Run get-open-prs every 5 minutes";
      Wants = "network-online.target";
      After = "network-online.target";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
    Timer = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "get-open-prs.service";
    };
  };

}
