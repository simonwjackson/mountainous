{
  lib,
  writeShellApplication,
  wireguard-tools,
  iproute2,
  curl,
  gnugrep,
  gnused,
  coreutils,
  procps,
  iptables,
  util-linux,
  glibc,
  iputils,
  ...
}:
(writeShellApplication {
  name = "vpn-ns";
  runtimeInputs = [
    wireguard-tools
    iproute2
    curl
    gnugrep
    gnused
    coreutils
    procps # sysctl
    iptables # iptables
    util-linux # runuser
    glibc.getent # getent for DNS lookups
    iputils # ping for health checks
  ];
  text = builtins.readFile ./vpn-ns.sh;
})
// {
  meta = with lib; {
    description = "Run commands inside a WireGuard VPN namespace";
    mainProgram = "vpn-ns";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
