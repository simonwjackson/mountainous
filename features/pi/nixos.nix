{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.pi;

  basePi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;

  # Prepend the skills' runtime tools (python, ripgrep, fd, grep) to PATH so
  # they're available to every process pi spawns, independent of the ambient
  # shell. The upstream module re-wraps this in its own launcher via getExe,
  # so meta.mainProgram must survive the join.
  piWithTools =
    if cfg.runtimePackages == []
    then basePi
    else
      pkgs.symlinkJoin {
        name = "pi-with-tools";
        paths = [basePi];
        nativeBuildInputs = [pkgs.makeWrapper];
        postBuild = ''
          wrapProgram $out/bin/pi \
            --prefix PATH : ${lib.makeBinPath cfg.runtimePackages}
        '';
        meta = basePi.meta or {} // {mainProgram = "pi";};
      };
in {
  # Pull in the upstream NixOS module (programs.pi.coding-agent.*). We keep
  # the upstream option path untouched and only forward our wrapped knobs
  # in `config` — same shape as other extended-upstream features.
  imports = [inputs.pi.nixosModules.default];

  config = mkIf cfg.enable {
    programs.pi.coding-agent = {
      enable = true;
      package = piWithTools;
      rules = cfg.rules;
      extraArgs = cfg.extraArgs;
      environment = cfg.environment;
    };

    # pi.nix publishes prebuilt closures to pi.cachix.org. Add it to the
    # trusted lists so hosts that opt in can use it without per-machine
    # nix config tweaks. Matches the existing core-preset cache pattern.
    nix.settings = {
      trusted-substituters = ["https://pi.cachix.org"];
      trusted-public-keys = [
        "pi.cachix.org-1:lGeoGJaZ5ZDabuRzkcD5EBTNnDM4HJ1vqeOxlWk1Flk="
      ];
    };
  };
}
