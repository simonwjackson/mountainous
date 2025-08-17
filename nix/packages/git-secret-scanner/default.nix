{
  lib,
  pkgs,
  stdenv,
  bun,
  ...
}:
stdenv.mkDerivation {
  pname = "git-secret-scanner";
  version = "1.0.0";

  src = ./.;

  buildInputs = with pkgs; [bash git bun gum];

  installPhase = ''
    mkdir -p $out/bin

    # Substitute the bun and gum paths in the script
    substitute git-secret-scanner.sh $out/bin/git-secret-scanner \
      --replace "bun x @anthropic-ai/claude-code" "${bun}/bin/bun x @anthropic-ai/claude-code" \
      --replace "gum " "${pkgs.gum}/bin/gum "

    chmod +x $out/bin/git-secret-scanner
  '';

  meta = with lib; {
    description = "Git secret scanner using Claude AI to detect exposed secrets in git repositories";
    homepage = "https://github.com/simonwjackson/mountainous";
    license = licenses.mit;
    maintainers = ["simonwjackson"];
    platforms = platforms.unix;
  };
}
