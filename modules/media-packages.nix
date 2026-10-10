# Pin application releases separately from the host operating system.
{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      media = import inputs.nixpkgs-media {
        system = pkgs.stdenv.hostPlatform.system;
        config.allowUnfree = true;
      };
      releases = {
        sonarr = "4.0.16.2944";
        radarr = "6.0.4.10291";
        prowlarr = "2.3.0.5236";
        nzbget = "26.0";
        transmission = "4.1.1";
      };
      runtime = {
        inherit (media)
          sonarr
          radarr
          prowlarr
          nzbget
          ;
        transmission = media.transmission_4;
      };
      matches = builtins.all (name: runtime.${name}.version == releases.${name}) (
        builtins.attrNames releases
      );
    in
    {
      packages.media-migration-runtime =
        assert matches;
        pkgs.buildEnv {
          name = "media-migration-runtime";
          paths = builtins.attrValues runtime;
        };
      packages.media-tsnet-proxy =
        inputs.gomod2nix-rakku.legacyPackages.${pkgs.stdenv.hostPlatform.system}.buildGoApplication
          {
            pname = "media-tsnet-proxy";
            version = "1.1.0";
            src = ../packages/media-tsnet-proxy;
            modules = ../packages/media-tsnet-proxy/gomod2nix.toml;
            ldflags = [
              "-s"
              "-w"
            ];
            doCheck = true;
          };
      checks = {
        media-releases =
          assert matches;
          pkgs.runCommand "media-releases" { } ''
            mkdir -p "$out"
            printf '%s\n' '${builtins.toJSON releases}' > "$out/releases.json"
          '';
        media-state = import ../tests/media-state.nix {
          inherit pkgs;
          nzbget = media.nzbget;
          transmission = media.transmission_4;
        };
        media-runtime = import ../tests/media-runtime.nix { inherit pkgs inputs; };
      };
    };
}
