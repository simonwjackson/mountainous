# Only Unzen's main network provides home egress. media-vpn stays in its netns.
{ self, ... }:
{
  nixos.modules.home-exit-node = { config, pkgs, ... }: {
    mountainous.tailscale.routingFeatures = "both";
    systemd.services.tailscale-home-exit = {
      description = "Advertise home egress without changing the host's own route";
      wantedBy = [ "multi-user.target" ];
      requires = [ "tailscaled.service" ];
      after = [ "tailscaled.service" "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.tailscale}/bin/tailscale set --advertise-exit-node";
        Restart = "on-failure";
        RestartSec = 10;
      };
    };
    assertions = [{
      assertion = config.networking.hostName == "unzen";
      message = "The home exit node placement is Unzen, never a cloud host.";
    }];
  };
  perSystem = { pkgs, ... }: {
    checks.home-exit-node =
      let c = self.nixosConfigurations.unzen.config;
      in
      assert c.services.tailscale.useRoutingFeatures == "both";
      assert c.systemd.services.tailscale-home-exit.serviceConfig.ExecStart == "${c.services.tailscale.package}/bin/tailscale set --advertise-exit-node";
      pkgs.runCommand "home-exit-node" {} "touch $out";
  };
}
