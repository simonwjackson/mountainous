{
  lib,
  pkgs,
  inputs,
  stdenv,
  makeWrapper,
  ...
}:
stdenv.mkDerivation {
  name = "git-commit-message";
  version = "0.1.0";

  src = ./.;

  nativeBuildInputs = [makeWrapper];

  # buildInputs = with pkgs; [
  #   bash
  #   git
  #   jq
  #   claude
  # ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${./git-commit-message.sh} $out/bin/git-commit-message
    chmod +x $out/bin/git-commit-message

    wrapProgram $out/bin/git-commit-message \
      --prefix PATH : ${lib.makeBinPath (with pkgs; [
      bash
      git
      jq
    ])}
  '';

  meta = with lib; {
    description = "Generate git commit messages using Claude Code";
    mainProgram = "git-commit-message";
    platforms = platforms.all;
  };
}

