{
  config,
  lib,
  ...
}: {
  # openresolv restarts libc nscd to invalidate its cache on every DNS update.
  # nsncd does not cache. glibc reloads resolv.conf itself; restarting this proxy
  # on the NetworkManager/tailscale boot burst only exhausts systemd's limiter.
  networking.resolvconf.extraConfig = lib.mkIf config.services.nscd.enableNsncd ''
    libc_restart=':'
  '';
}
