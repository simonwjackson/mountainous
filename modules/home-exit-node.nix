# Rakku provides home egress. The container remains fail closed if it loses this route.
{ self, ... }:
{
  nixos.modules.home-exit-node =
    { config, pkgs, ... }:
    {
      mountainous.tailscale.routingFeatures = "both";
      systemd.services.tailscale-home-exit = {
        description = "Advertise home egress without changing the host's own route";
        wantedBy = [ "multi-user.target" ];
        requires = [ "tailscaled.service" ];
        wants = [ "network-online.target" ];
        after = [
          "tailscaled.service"
          "network-online.target"
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.tailscale}/bin/tailscale set --advertise-exit-node";
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
      assertions = [
        {
          assertion = config.networking.hostName == "rakku";
          message = "The home exit node placement is Rakku, never a cloud host.";
        }
      ];
    };
  perSystem =
    { pkgs, ... }:
    {
      checks.home-exit-node =
        let
          c = self.nixosConfigurations.rakku.config;
        in
        assert !(self.nixosConfigurations.unzen.config.systemd.services ? tailscale-home-exit);
        assert c.services.tailscale.useRoutingFeatures == "both";
        assert
          c.systemd.services.tailscale-home-exit.serviceConfig.ExecStart
          == "${c.services.tailscale.package}/bin/tailscale set --advertise-exit-node";
        pkgs.runCommand "home-exit-node" { } "touch $out";
    };
}
