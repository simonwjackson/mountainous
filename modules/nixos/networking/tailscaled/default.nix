{
  lib,
  pkgs,
  inputs,
  system,
  target,
  format,
  virtual,
  systems,
  config,
  ...
}: let
  cfg = config.mountainous.networking.tailscaled;
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
  options.mountainous.networking.tailscaled = {
    enable = lib.mkEnableOption "Tailscale Daemon";

    isMobileNixos = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Mobile Nixos 2024-04-27: This kernel does not support rpfilter
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.str;
      description = "Extra args";
      default = "";
    };

    exit-node = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Exit node
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    age.secrets."tailscale".file = ../../../../secrets/tailscale.age;

    environment.systemPackages = with pkgs; [
      tailscale # make the tailscale command usable to users
    ];

    systemd.services.mobileNixosTailscaled = lib.mkIf cfg.isMobileNixos {
      description = "Tailscale Daemon";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        ExecStart = "${pkgs.tailscale}/bin/tailscaled";
        Restart = "always";
        RestartSec = 5;
      };
    };

    services.tailscale = lib.mkIf (!cfg.isMobileNixos) {
      enable = true;
      useRoutingFeatures =
        if cfg.exit-node
        then "both"
        else "client";
    };

    networking.firewall = {
      trustedInterfaces = lib.mkAfter ["tailscale0"];
      allowedUDPPorts = [config.services.tailscale.port];
    };

    systemd.services.tailscale-autoconnect = {
      description = "Automatic connection to Tailscale";

      # make sure tailscale is running before trying to connect to tailscale
      after = ["network-pre.target" "tailscale.service"];
      wants = ["network-pre.target" "tailscale.service"];
      wantedBy = ["multi-user.target"];

      serviceConfig.Type = "oneshot";

      script =
        ''
           # wait for tailscaled to settle
           sleep 2

           # check if we are already authenticated to tailscale
           status="$(${pkgs.tailscale}/bin/tailscale status -json | ${pkgs.jq}/bin/jq -r .BackendState)"
           if [ $status = "Running" ]; then # if so, then do nothing
             exit 0
           fi

           # otherwise authenticate with tailscale
          ${pkgs.tailscale}/bin/tailscale up ${pkgs.args} --authkey file:''
        + config.age.secrets."tailscale".path;
    };
  };
}
