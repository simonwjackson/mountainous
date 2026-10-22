# Hosts that never build.
#
# Rakku has 8 GB of memory and runs Home Assistant and the household's
# assistants; Tate is an eMMC Gemini Lake box. A build on either competes with
# the services it runs. Everything they run is built on another machine and
# copied in: the system with rakku-switch-target or `nixos-rebuild
# --target-host`, the assistant's application with pi-assistant-deploy. With
# no local jobs and no remote builders, a build that reaches one of them fails
# at once instead of starting; anything a binary cache holds still downloads.
{ self, ... }:
let
  # The machines that must never build, by name, so dropping the layer from
  # one of them fails the flake instead of quietly letting it build again.
  neverBuild = [
    "rakku"
    "tate"
  ];
in
{
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatMap (
        host:
        let
          settings = self.nixosConfigurations.${host}.config.nix.settings;
          want = ok: msg: lib.optional (!ok) "${host}: ${msg}";
        in
        want (settings.max-jobs == 0) "max-jobs is ${toString settings.max-jobs}, not 0"
        ++ want ((settings.builders or "") == "") "it has remote builders"
      ) neverBuild;
    in
    {
      checks.no-builds =
        if problems == [ ] then
          pkgs.runCommand "no-builds-check" { } "touch $out"
        else
          throw "no-builds:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.no-builds =
    { lib, ... }:
    {
      nix.settings.max-jobs = lib.mkForce 0;
      nix.settings.builders = lib.mkForce "";
      nix.distributedBuilds = lib.mkForce false;
    };
}
