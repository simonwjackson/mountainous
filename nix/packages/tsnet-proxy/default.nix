{
  lib,
  buildGoApplication,
  ...
}:
buildGoApplication rec {
  pname = "tsnet-proxy";
  version = "1.0.0";

  src = ./.;

  # Use gomod2nix.toml for dependency management
  modules = ./gomod2nix.toml;

  # Build flags
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  # Skip tests since we don't have any yet
  doCheck = false;

  meta = with lib; {
    description = "Lightweight reverse proxy using Tailscale's tsnet library";
    homepage = "https://github.com/simonwjackson/mountainous";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
