{pkgs, ...}: let
  dependencies = with pkgs; [
    bash
    curl
    gnugrep
    gum
    yt-dlp
    mpv
    jq
    coreutils
  ];
in
  pkgs.stdenv.mkDerivation {
    name = "deadwax";
    src = ./.;

    nativeBuildInputs = with pkgs; [
      makeWrapper
    ];

    buildInputs = dependencies;

    installPhase = ''
      # Create directories
      mkdir -p $out/bin $out/lib

      # Copy all files preserving structure
      cp -r bin/. $out/bin/
      cp -r lib/. $out/lib/

      # Make scripts executable
      find $out -type f -name "*.sh" -exec chmod +x {} +
      find $out/lib/plugins -type f -not -name "*.json" -exec chmod +x {} +

      # Wrap main script with runtime dependencies
      makeWrapper $out/bin/deadwax.sh $out/bin/deadwax \
        --prefix PATH : ${pkgs.lib.makeBinPath dependencies}
    '';
  }
