{
  producerRoot,
  selector,
  retirement,
}: let
  producer = import ../scripts/federation-cutover/producer.nix {
    producerRoot = builtins.toPath producerRoot;
  };
  lock = builtins.fromJSON (builtins.readFile ../flake.lock);
  pin = lock.nodes.${lock.nodes.root.inputs.nixpkgs}.locked;
  pkgs = import (builtins.fetchTree pin) {system = "x86_64-linux";};
  sunshinePackage = builtins.storePath "/nix/store/1m3qwaxx068d30y9559qx7ppz2xaiz01-sunshine-korri-2025.924.154138-korri";
  package = import ../scripts/federation-cutover {
    inherit pkgs;
    inherit (producer) korridPackage;
    selectorPackage = builtins.storePath selector;
    sunshineRetirement = builtins.storePath retirement;
  };
in {
  inherit package;
  probes = import ./federation-cutover.nix {
    inherit pkgs package sunshinePackage;
    probesOnly = true;
    selectorPackage = builtins.storePath selector;
  };
  proofs = import ./federation-cutover.nix {
    inherit pkgs package sunshinePackage;
    proofsOnly = true;
    selectorPackage = builtins.storePath selector;
  };
  faults = import ./federation-cutover.nix {
    inherit pkgs package sunshinePackage;
    faultsOnly = true;
    selectorPackage = builtins.storePath selector;
  };
  smoke = import ./federation-cutover.nix {
    inherit pkgs package sunshinePackage;
    smoke = true;
    selectorPackage = builtins.storePath selector;
  };
  vm = import ./federation-cutover.nix {
    inherit pkgs package sunshinePackage;
    selectorPackage = builtins.storePath selector;
  };
}
