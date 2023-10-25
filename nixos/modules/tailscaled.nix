{
  pkgs,
  config,
  lib,
  rootPath,
  ...
}:
with lib; let
  cfg = config.services.tailscaled;
  args =
    cfg.extraArgs
    + " "
    + "--advertise-exit-node="
    + (
      if cfg.exit-node
      then "true"
      else "false"
    );
in {
  options.services.tailscaled = {
    enable = mkEnableOption "Tailscale Daemon";

    extraArgs = mkOption {
      type = types.str;
      description = "Extra args";
      default = "";
    };

    exit-node = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Exit node
      '';
    };
  };

  config = mkIf cfg.enable {
    age.secrets."tailscale".file = rootPath + /secrets/tailscale.age;

    environment.systemPackages = with pkgs; [
      tailscale # make the tailscale command usable to users
    ];

    # enable the tailscale service
    services.tailscale = {
      enable = true;
      useRoutingFeatures =
        if cfg.exit-node
        then "both"
        else "client";
    };

    networking.firewall = {
      # always allow traffic from your Tailscale network
      trustedInterfaces = lib.mkAfter ["tailscale0"];

      # allow the Tailscale UDP port through the firewall
      allowedUDPPorts = [config.services.tailscale.port];
    };

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = ["network-pre.target" "tailscale.service"];
      wants = ["network-pre.target" "tailscale.service"];
      wantedBy = ["multi-user.target"];

      # set this service as a oneshot job
      serviceConfig.Type = "oneshot";

      # have the job run this shell script
      script = with pkgs;
        ''
          # wait for tailscaled to settle
          sleep 2

          # check if we are already authenticated to tailscale
          status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
          if [ $status = "Running" ]; then # if so, then do nothing
            exit 0
          fi

          # otherwise authenticate with tailscale
          ${tailscale}/bin/tailscale up ${args} --authkey file:''
        + config.age.secrets."tailscale".path;
    };
  };
}
