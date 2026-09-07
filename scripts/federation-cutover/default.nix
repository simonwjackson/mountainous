# Standalone consumer. No host module or flake activation/deployment wiring.
# Inputs must be reviewed immutable producer packages, not mutable executable paths.
{
  pkgs,
  korridPackage,
  selectorPackage,
  sunshineRetirement,
}: let
  verifier = korridPackage.overrideAttrs (old: {
    pname = "federation-cutover-korrid";
    src = pkgs.runCommand "federation-cutover-korrid-source" {} ''
      mkdir -p "$out"
      cp -R --no-preserve=mode,ownership ${old.src}/. "$out/"
      mkdir -p "$out/src/bin"
      cp ${./owner-verify.rs} "$out/src/bin/federation-owner-verify.rs"
    '';
    # Crane has already composed buildPhase from cargoBuildExtraArgs at this
    # seam. Append the public consumer bin; do not patch producer APIs or crypto.
    buildPhase =
      old.buildPhase
      + ''
        cargo build --release --locked --bin federation-owner-verify
      '';
    postInstall =
      old.postInstall
      + ''
        install -Dm755 target/release/federation-owner-verify "$out/bin/federation-owner-verify"
      '';
  });
  tools = {
    systemctl = "${pkgs.systemd}/bin/systemctl";
    systemdRun = "${pkgs.systemd}/bin/systemd-run";
    nixEnv = "${pkgs.nix}/bin/nix-env";
    nft = "${pkgs.nftables}/bin/nft";
    curl = "${pkgs.curl}/bin/curl";
    openssl = "${pkgs.openssl}/bin/openssl";
    korrid = "${verifier}/bin/korrid";
    ownerVerify = "${verifier}/bin/federation-owner-verify";
    selector = "${selectorPackage}/bin/korri-bundle-select";
    retire = "${sunshineRetirement}/bin/sunshine-retire-all-clients";
  };
in
  assert pkgs.lib.versions.major pkgs.systemd.version == "259";
    pkgs.runCommand "federation-cutover-supervisor" {
      nativeBuildInputs = [pkgs.makeWrapper];
      passthru = {inherit verifier tools;};
    } ''
      test -x ${verifier}/bin/federation-owner-verify
      test -x ${selectorPackage}/bin/korri-bundle-select
      test -x ${sunshineRetirement}/bin/sunshine-retire-all-clients
      mkdir -p "$out/lib" "$out/bin"
      cp ${../../scripts/federation_cutover.py} "$out/lib/federation_cutover.py"
      cp ${../../scripts/federation_isolation.py} "$out/lib/federation_isolation.py"
      cp ${../../scripts/federation_network_isolation.py} "$out/lib/federation_network_isolation.py"
      cp ${../../scripts/federation_network_isolation.nft} "$out/lib/federation_network_isolation.nft"
      cp ${pkgs.writeText "cutover-tools.json" (builtins.toJSON tools)} "$out/lib/tools.json"
      makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/federation-cutover" \
        --add-flags "-I -B $out/lib/federation_cutover.py" \
        --set PATH ${pkgs.lib.makeBinPath [pkgs.systemd pkgs.coreutils]} \
        --unset PYTHONPATH --unset PYTHONHOME
    ''
