# The fleet's install tool: `nix run .#install -- <host> <user@address>`.
#
# DESTRUCTIVE. It installs a host from scratch onto a remote machine that runs
# any Linux with SSH, and wipes every disk in the host's disko layout. It does
# not update a running host. Use nixos-rebuild for that.
#
# The app wraps scripts/install-remote. The script holds the logic; the app
# pins what the script would otherwise take from NIX_PATH:
#
#   - its shell tools come from this flake's nixpkgs
#   - nixos-anywhere is the fail-closed `nixos-anywhere-verified` build
#   - host evaluation uses the flake source the app was built from, so the
#     system installed is the system `nix run` evaluated
{
  self,
  lib,
  ...
}:
{
  perSystem =
    {
      pkgs,
      system,
      self',
      ...
    }:
    let
      install = pkgs.writeShellApplication {
        name = "mountainous-install";
        runtimeInputs = with pkgs; [
          coreutils
          findutils
          gnugrep
          gnused
          jq
          openssh
          ssh-to-age
        ];
        text = ''
          export MOUNTAINOUS_REPO=${self}
          export MOUNTAINOUS_PROG="nix run .#install --"
          export MOUNTAINOUS_NIXOS_ANYWHERE=${lib.getExe' self'.packages.nixos-anywhere-verified "nixos-anywhere"}
          exec bash "$MOUNTAINOUS_REPO/scripts/install-remote" "$@"
        '';
      };
    in
    # nixos-anywhere-verified is built only for x86_64-linux (unzen-installer.nix).
    lib.mkIf (system == "x86_64-linux") {
      packages.install = install;
      apps.install = {
        type = "app";
        program = lib.getExe install;
        meta.description = "Install a host onto a remote Linux machine (destroys its disks)";
      };

      # The app must refuse to run without both arguments, before it touches
      # the network, and must point at the pinned nixos-anywhere.
      checks.install-app = pkgs.runCommand "install-app-check" { } ''
        set +e
        msg=$(${lib.getExe install} 2>&1); rc=$?
        set -e
        echo "$msg"
        [ "$rc" -ne 0 ] || { echo "expected a non-zero exit with no arguments"; exit 1; }
        echo "$msg" | grep -qF 'usage: nix run .#install -- <host> <user@address>'
        anywhere=$(grep -o 'MOUNTAINOUS_NIXOS_ANYWHERE=[^ ]*' ${lib.getExe install} | cut -d= -f2)
        [ -x "$anywhere" ] || { echo "pinned nixos-anywhere is not executable: $anywhere"; exit 1; }
        grep -qF '"-F" "/dev/null" "-o" "StrictHostKeyChecking=yes"' "$(dirname "$anywhere")/.nixos-anywhere-wrapped" \
          || { echo "pinned nixos-anywhere lost its fail-closed host key patch"; exit 1; }
        touch $out
      '';
    };
}
