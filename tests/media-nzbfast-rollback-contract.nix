# Run with nix eval --impure --expr 'import ./tests/media-nzbfast-rollback-contract.nix'.
# Compare the real rollback units with the admitted pre-NZBFAST Cairn revision.
let
  repository = toString ../.;
  revision = "02f89d053ac484302562e3b81e7880f721c5134e";
  flake = builtins.getFlake repository;
  baseline =
    (builtins.getFlake "git+file://${repository}?rev=${revision}").nixosConfigurations.unzen.config;
  rollback =
    mode:
    (flake.nixosConfigurations.unzen.extendModules {
      modules = [
        ({ lib, ... }: {
          # One switch only: the cutover's nzbfast.held=false stays unchanged.
          mountainous.features.media-applications.usenet = lib.mkForce mode;
        })
      ];
    }).config;
  comparison =
    mode:
    let
      config = rollback mode;
    in
    {
      nzbgetExecStartEqual =
        config.systemd.services.nzbget.serviceConfig.ExecStart
        == baseline.systemd.services.nzbget.serviceConfig.ExecStart;
      nzbgetUnitConfigEqual =
        config.systemd.services.nzbget.unitConfig == baseline.systemd.services.nzbget.unitConfig;
      usenetProxyUnitByteEqual =
        config.systemd.units."tsnet-proxy-nzbget.service".text
        == baseline.systemd.units."tsnet-proxy-nzbget.service".text;
      usenetProxyGateEqual =
        config.systemd.services.tsnet-proxy-nzbget.unitConfig
        == baseline.systemd.services.tsnet-proxy-nzbget.unitConfig;
    };
  comparisons = builtins.listToAttrs (
    map
      (mode: {
        name = mode;
        value = comparison mode;
      })
      [
        "nzbget"
        "both"
      ]
  );
in
assert builtins.all (result: builtins.all (value: value) (builtins.attrValues result)) (
  builtins.attrValues comparisons
);
{
  status = "pass";
  baselineRevision = revision;
  inherit comparisons;
}
