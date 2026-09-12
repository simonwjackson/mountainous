{lib, ...}: let
  inherit (lib) mkEnableOption mkOption types;
in {
  imports = [
    ./nixos.nix
  ];

  options.mountainous.features.korri-cache = {
    enable = mkEnableOption "Korri's signed Nix cache as a substituter";

    publish = {
      enable = mkEnableOption ''
        publishing this machine's own builds to Korri's cache.

        The Nix post-build hook stages every path this machine builds, and the
        uploader drops the ones a public cache already serves. It has no way to
        tell Korri's outputs from anything else built here, so a private build
        that no public cache carries would be published to a public release.
        Only turn this on for a machine whose local builds may all be public
      '';

      signingKeyFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Path to this machine's Nix cache signing secret, readable by root and
          outside the Nix store. Its public half must be listed in Korri's
          nix/cache/identity.nix, or consumers reject what this machine signs.
        '';
        example = "/etc/nix/korri-cache-key.secret";
      };

      githubTokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          Path to a systemd EnvironmentFile holding `GH_TOKEN=<token>`, where the
          token has contents write access to the cache repository and nothing
          else. The uploader runs as root on a timer and cannot use an
          interactive `gh` login.
        '';
        example = "/run/agenix/korri-cache-github-token";
      };

      stagingDir = mkOption {
        type = types.str;
        default = "/var/cache/korri-nix-cache";
        description = "Local signed file cache the post-build hook writes into.";
      };

      schedule = mkOption {
        type = types.str;
        default = "hourly";
        description = "Systemd OnCalendar expression for the upload timer.";
      };
    };
  };
}
