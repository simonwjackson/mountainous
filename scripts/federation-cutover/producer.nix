# Build public producer source only. Never export the worktree as a flake input.
{producerRoot}: let
  lock = builtins.fromJSON (builtins.readFile (producerRoot + "/flake.lock"));
  source = name: builtins.fetchTree lock.nodes.${name}.locked;
  pkgs = import (source "nixpkgs") {
    system = "x86_64-linux";
    config.allowUnfree = true;
    overlays = [(import (source "rust-overlay"))];
  };
  lib = pkgs.lib;
  prefixes = [
    "services/korrid/src"
    "services/korrid/examples"
    "services/korrid/Cargo.toml"
    "services/korrid/Cargo.lock"
    "services/korrid/package.nix"
    "services/korrid/proseql-source.nix"
    "services/korrid/package-runtime-check.sh"
    "services/korrid/plugins/android-app.plugin.ts"
    "services/inputd/nix/retroarch-inputplumber-autoconfig.nix"
    "plugins/mgba/plugin.ts"
    "plugins/moonlight/plugin.ts"
    "plugins/retroarch/plugin.ts"
  ];
  public = builtins.path {
    name = "federation-cutover-public-producer";
    path = producerRoot;
    filter = path: type: let
      relative = lib.removePrefix (toString producerRoot + "/") (toString path);
    in
      toString path
      == toString producerRoot
      || builtins.any (
        prefix:
          relative
          == prefix
          || lib.hasPrefix (prefix + "/") relative
          || (type == "directory" && lib.hasPrefix (relative + "/") prefix)
      )
      prefixes;
  };
  crane = {mkLib = pkgs: import (source "crane") {inherit pkgs;};};
in {
  inherit pkgs;
  korridPackage = import (public + "/services/korrid/package.nix") {
    inherit pkgs crane;
    proseql = source "proseql";
  };
}
