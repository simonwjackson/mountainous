# Gives tagged fleet devices a person at Claw's Tailscale Serve; see main.go.
# Standard library only, so there is no vendored module set. Tests run in the build.
{ pkgs }:
pkgs.buildGoModule {
  pname = "claw-identity-proxy";
  version = "1.0.0";
  src = ../packages/claw-identity-proxy;
  vendorHash = null;
  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];
}
