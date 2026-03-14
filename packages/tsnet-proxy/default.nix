{
  lib,
  buildGoModule,
  ...
}:
buildGoModule rec {
  pname = "tsnet-proxy";
  version = "1.0.0";

  src = ./.;

  vendorHash = "sha256-b0sf2rmvyPZQX1MVK28qXO+xktM4SQM+FkXuLQJcgGY=";

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
