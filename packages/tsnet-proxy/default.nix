{
  lib,
  buildGoModule,
  ...
}:
buildGoModule rec {
  pname = "tsnet-proxy";
  version = "1.0.0";

  src = ./.;

  vendorHash = null;  # Uses go.sum directly

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Lightweight reverse proxy using Tailscale's tsnet library";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
