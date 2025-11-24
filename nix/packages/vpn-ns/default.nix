{
  lib,
  writeShellApplication,
  wireguard-tools,
  iproute2,
  curl,
  gnugrep,
  gnused,
  coreutils,
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
  ];
  text = builtins.readFile ./vpn-ns.sh;
})
// {
  meta = with lib; {
    description = "Run commands inside a WireGuard VPN namespace";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
