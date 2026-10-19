{
  pkgs,
  config,
}: let
  conf = pkgs.writeText "zao-resolvconf.conf" config.environment.etc."resolvconf.conf".text;
in
  assert config.services.nscd.enableNsncd;
  assert !(config.systemd.services.nscd.unitConfig ? StartLimitIntervalSec);
  assert !(config.systemd.services.nscd.unitConfig ? StartLimitBurst);
    pkgs.runCommand "zao-nsncd-no-resolver-restart" {} ''
      source ${conf}
      test "$libc_restart" = ':'
      for update in $(seq 1 12); do
        eval "$libc_restart"
      done
      touch "$out"
    ''
