# nix eval --impure --expr 'import ./tests/media-scryer-rollback-contract.nix {}'
# ARR uses the original validator contents AND basename, retaining store paths.
{
  flake ? builtins.getFlake (toString ../.),
  repository ? toString ../.,
}:
let
  revision = "32f1b351a3ef644628fa13d45a1903f5acafc637";
  baseline =
    (builtins.getFlake "git+file://${repository}?rev=${revision}").nixosConfigurations.unzen.config;
  rollback =
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        ({ lib, ... }: { mountainous.features.media-applications.library = lib.mkForce "arr"; })
      ];
    }).config;
  names = [
    "sonarr.service"
    "radarr.service"
    "tsnet-proxy-sonarr.service"
    "tsnet-proxy-radarr.service"
  ];
  comparisons =
    builtins.listToAttrs (
      map (name: {
        inherit name;
        value = rollback.systemd.units.${name}.text == baseline.systemd.units.${name}.text;
      }) names
    )
    // {
      # NixOS declares these filesystem units through fstab; systemd generates
      # them at boot. Compare the exact generator input, not absent static units.
      fstabByteEqual = rollback.environment.etc.fstab.text == baseline.environment.etc.fstab.text;
      bindfsAndMergerfsDefinitionsByteEqual =
        builtins.all
          (path: builtins.toJSON rollback.fileSystems.${path} == builtins.toJSON baseline.fileSystems.${path})
          [
            "/srv/media-library-view/tv"
            "/srv/media-library-view/movies"
            "/srv/range/media/tv"
            "/srv/range/media/movies"
          ];
      leakAuditByteEqual =
        rollback.environment.etc."media-vpn-leak-audit.json".text
        == baseline.environment.etc."media-vpn-leak-audit.json".text;
    };
in
assert builtins.all (value: value) (builtins.attrValues comparisons);
{
  status = "pass";
  baselineRevision = revision;
  inherit comparisons;
}
