{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf;
  cfg = config.mountainous.features.pi;
  # pi.nix has no nix-on-droid module; just install the binary. The wrapper
  # options (rules, extraArgs, environment) intentionally aren't honored on
  # droid until someone needs them — keeps the droid path narrow.
  basePi = inputs.pi.packages.${pkgs.stdenv.hostPlatform.system}.coding-agent;

  # Prepend the skills' runtime tools (python, ripgrep, fd, grep) to PATH so
  # they're available to every process pi spawns, independent of the ambient
  # shell.
  piPackage =
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
  config = mkIf cfg.enable {
    environment.packages = [piPackage];
  };
}
