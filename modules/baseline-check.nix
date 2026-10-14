# The fleet standard, checked on every host.
#
# A host may differ from the base layer, but only on purpose: each exception
# below names the host or layer that is allowed to.
{ config, self, ... }:
let
  hosts = config.nixos.hosts;
in
{
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          name: host:
          let
            c = self.nixosConfigurations.${name}.config;
            has = layer: builtins.elem layer host.layers;
            want = ok: msg: lib.optional (!ok) "${name}: ${msg}";
          in
          want (
            c.boot.kernel.sysctl."net.ipv4.tcp_congestion_control" == "bbr"
          ) "congestion control is not bbr"
          ++ want (builtins.elem "tcp_bbr" c.boot.kernelModules) "tcp_bbr is not loaded"
          ++ want c.zramSwap.enable "zram swap is off"
          ++ want (
            c.users.users.simon.uid == (if name == "rakku" then 1001 else 1000)
          ) "simon has the wrong uid"
          ++ want (
            has "korri" || !c.services.openssh.openFirewall
          ) "SSH is open outside Tailscale (only Korri devices may)"
          ++ want (builtins.elem 22 c.networking.firewall.interfaces.tailscale0.allowedTCPPorts) "SSH is closed on Tailscale"
          ++ want (
            !(has "server") || (c.time.timeZone == "UTC" && !c.services.automatic-timezoned.enable)
          ) "a server is not on UTC"
          ++ want (!(has "builder") || c.nix.settings.substituters != [ ]) "a builder has no substituters"
        ) hosts
      );
    in
    {
      checks.baseline =
        if problems == [ ] then
          pkgs.runCommand "baseline" { } "touch $out"
        else
          throw "fleet baseline:\n  ${lib.concatStringsSep "\n  " problems}";
    };
}
