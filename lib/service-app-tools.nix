{ pkgs, lib }:
let
  helpers = [
    "service-apps-check-source-target"
    "service-apps-build-system-target"
    "service-apps-host-target"
    "service-apps-stage-source-target"
    "service-apps-run-update-target"
    "service-apps-rollback-probe"
    "service-apps-cutover"
  ];
  runtime = lib.makeBinPath [
    pkgs.nix
    pkgs.git
    pkgs.openssh
    pkgs.systemd
    pkgs.coreutils
    pkgs.diffutils
  ];
in
pkgs.runCommand "service-app-tools" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
  mkdir -p "$out/bin" "$out/libexec/service-apps"
  cp ${../scripts/service_apps.py} "$out/libexec/service-apps/service_apps.py"
  ${lib.concatMapStringsSep "\n" (helper: ''
    cp ${../scripts + "/${helper}"} "$out/libexec/service-apps/${helper}"
    makeWrapper ${pkgs.python3}/bin/python3 "$out/bin/${helper}" \
      --add-flags "$out/libexec/service-apps/${helper}" \
      --prefix PATH : ${runtime}
  '') helpers}
''
