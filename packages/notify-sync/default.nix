# The notify CLI from the cairn branch, built from a pinned, pushed revision
# (inputs.notify-sync-src). Zao uses it to send storage alerts until it moves
# to cairn. Integration tests run in cairn's own check; this build skips them.
{
  inputs,
  stdenv,
  go,
  ...
}:
inputs.gomod2nix.legacyPackages.${stdenv.hostPlatform.system}.buildGoApplication {
  pname = "notify-sync";
  version = "1.0.0";
  src = "${inputs.notify-sync-src}/packages/notify-sync";
  modules = "${inputs.notify-sync-src}/packages/notify-sync/gomod2nix.toml";
  inherit go;
  CGO_ENABLED = 0;
  doCheck = false;
}
