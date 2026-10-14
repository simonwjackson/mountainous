# One tailnet HTTPS name in front of one local backend. Rakku runs one per name.
# The source stays in its own directory so its store path does not change when
# this file changes.
{ buildGoApplication }:
buildGoApplication {
  pname = "tsnet-proxy";
  version = "1.0.0";
  src = ./tsnet-proxy;
  modules = ./tsnet-proxy/gomod2nix.toml;
  ldflags = [
    "-s"
    "-w"
  ];
  doCheck = false;
}
