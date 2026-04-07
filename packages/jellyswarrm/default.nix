{
  lib,
  rustPlatform,
  jellyfin-web,
  inputs,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "jellyswarrm";
  version = "0.2.1";

  src = inputs.jellyswarrm;

  cargoHash = "sha256-D3IOpcP9RXPmXJQcFibWaBShb6G4DXZSPe5hmqrgykM=";

  buildInputs = [
    jellyfin-web
  ];

  env = {
    # Skip internal UI build; use the nixpkgs jellyfin-web package instead
    JELLYSWARRM_SKIP_UI = "1";
  };

  preBuild = ''
    mkdir -p crates/jellyswarrm-proxy/static
    cp -r ${jellyfin-web}/share/jellyfin-web/* crates/jellyswarrm-proxy/static/
    cat > crates/jellyswarrm-proxy/static/ui-version.env <<EOF
    UI_VERSION=${jellyfin-web.version}
    UI_COMMIT=nix
    EOF
  '';

  meta = with lib; {
    description = "Reverse proxy to merge multiple Jellyfin servers into one";
    homepage = "https://github.com/LLukas22/Jellyswarrm";
    license = licenses.mit;
    mainProgram = "jellyswarrm-proxy";
  };
}
