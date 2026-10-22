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
          # modules/memory-guard.nix: no host may lock you out by running out of memory.
          ++ want (
            c.systemd.services.sshd.serviceConfig.MemoryMin or null == "64M"
          ) "sshd has no memory reserve"
          ++ want (
            c.systemd.slices.system.sliceConfig.MemoryMin or null != null
          ) "system.slice reserves no memory, so no reserve below it works"
          ++ want c.systemd.oomd.enableSystemSlice "systemd-oomd does not watch system.slice"
          ++ want (
            c.systemd.services.nix-daemon.serviceConfig.MemoryMax or null != null
          ) "nix-daemon has no MemoryMax"
          ++ want (
            !(lib.hasPrefix "/tmp" (c.systemd.services.nix-daemon.environment.TMPDIR or "/tmp"))
          ) "builds unpack in the tmpfs /tmp"
          ++ want (
            !(has "desktop") || !c.systemd.oomd.enableUserSlices
          ) "oomd watches a desktop's user slices and could end the whole session"
          ++ want (
            !(c.systemd.services.sshd.serviceConfig ? OOMScoreAdjust)
          ) "sshd has an OOMScoreAdjust, which every SSH login would inherit"
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
