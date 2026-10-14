# Verify the actual fleet mount with systemd's real tmpfiles/local-fs units.
{
  pkgs,
  unitText,
  systemd,
}:
let
  name = "var-lib-pi-simon-agent-settings.json.mount";
  unit = pkgs.writeText name unitText;
in
pkgs.writeShellScript "pi-boot-order" ''
  set -euo pipefail
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  cd "$work"
  mkdir -p units/local-fs.target.wants
  cp ${unit} units/${name}
  # Include both jobs in one boot transaction. A mount-only verification
  # does not pull in local-fs.target and can miss the ordering cycle.
  ln -s ../${name} units/local-fs.target.wants/${name}
  export SYSTEMD_UNIT_PATH="$PWD/units:${systemd}/example/systemd/system"
  ${systemd}/bin/systemd-analyze verify --man=no local-fs.target > verify.log 2>&1 || { cat verify.log; exit 1; }
  cat verify.log
  # systemd can return zero AFTER deleting a cyclic job. Check diagnostics too.
  if grep -E 'ordering cycle|Job .* deleted' verify.log; then exit 1; fi

  # Negative control proves this transaction detects the original cycle.
  sed -i 's/bind,ro,nofail/bind,ro/' units/${name}
  ${systemd}/bin/systemd-analyze verify --man=no local-fs.target > negative.log 2>&1 || true
  echo "Negative control: the original mount produces an ordering cycle"
  grep 'ordering cycle' negative.log
''
