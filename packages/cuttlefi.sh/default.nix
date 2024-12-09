{
  lib,
  writeShellApplication,
  bash,
  yq,
  yt-dlp,
  gum,
}:
writeShellApplication {
  name = "cuttlefish";

  runtimeInputs = [
    bash
    yq
    yt-dlp
    gum
  ];

  text = builtins.readFile ./cuttlefi.sh;
}
