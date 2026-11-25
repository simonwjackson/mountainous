# GitHub on every machine: `gh`, and git over HTTPS, signed in with no login.
#
# One token, `github-token` in secrets/fleet.yaml, signs in whoever may read
# it: members of the `github` group, and any service that receives it as the
# systemd credential `github-token` (LoadCredential). The `gh` on PATH is a
# wrapper that exports GH_TOKEN from the first of those it can read, so a
# fresh machine needs no `gh auth login`. A GH_TOKEN already in the
# environment wins. Git asks `gh` for github.com credentials.
#
# The token is the operator's, so it acts as him. A service lists the
# credential only when it should act as him too.
{ config, self, ... }:
let
  credential = "github-token";
  # Fleet hosts only; installer images have no mountainous options.
  hosts = builtins.attrNames config.nixos.enrolledHosts;
in
{
  # Enrolled hosts carry the signed-in gh and its token.
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatMap (
        host:
        let
          c = self.nixosConfigurations.${host}.config;
          want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
        in
        want (lib.elem c.mountainous.github.package c.environment.systemPackages) "gh is not installed"
        ++ want (c.sops.secrets ? ${credential}) "the ${credential} secret is not declared"
        ++ want (lib.elem "github" c.users.users.simon.extraGroups) "simon cannot read the GitHub token"
      ) hosts;
    in
    {
      checks.github =
        if problems == [ ] then
          pkgs.runCommand "github-check" { } "touch $out"
        else
          throw "github:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.base =
    {
      config,
      lib,
      pkgs,
      enrolled,
      ...
    }:
    let
      signIn = pkgs.writeShellApplication {
        name = "gh";
        text = ''
          if [ -z "''${GH_TOKEN:-}" ]; then
            for file in "''${CREDENTIALS_DIRECTORY:-/nonexistent}/${credential}" ${
              config.sops.secrets.${credential}.path
            }; do
              if [ -r "$file" ]; then
                GH_TOKEN=$(<"$file")
                export GH_TOKEN
                break
              fi
            done
          fi
          exec ${pkgs.gh}/bin/gh "$@"
        '';
      };
      # The wrapper first, so its bin/gh wins; gh's man pages and completions come along.
      gh =
        if !enrolled then
          pkgs.gh
        else
          pkgs.symlinkJoin {
            name = "gh-${pkgs.gh.version}";
            paths = [
              signIn
              pkgs.gh
            ];
          };
    in
    {
      options.mountainous.github.package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = "gh, signed in from the fleet token on enrolled hosts only.";
      };

      config = {
        mountainous.github.package = gh;

        sops.secrets.${credential} = lib.mkIf enrolled {
          group = "github";
          mode = "0440";
        };
        users.groups.github = lib.mkIf enrolled { };
        users.users.simon.extraGroups = lib.optional enrolled "github";

        environment.systemPackages = [ gh ];
        programs.git = {
          enable = true;
          config.credential."https://github.com".helper = "!${gh}/bin/gh auth git-credential";
        };
      };
    };
}
