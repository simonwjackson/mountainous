# The tandem rule (docs/plans/desktop-themes.md, "Tandem rule and parity
# ledger") as a check: Platinum and Windows 98 expose the same Desktop
# contract (every method or flag the shell routes to a Desktop, the omni
# view, web.css, the picker), or the ledger's parity-gaps block lists the
# gap with a reason. Node only; it reads the QML and the ledger as text.
{
  perSystem =
    { pkgs, ... }:
    {
      checks.theme-parity =
        pkgs.runCommand "theme-parity"
          {
            nativeBuildInputs = [ pkgs.nodejs ];
          }
          ''
            node ${./quickshell}/theme-dev/theme-parity.test.js ${./quickshell} ${../docs/plans/desktop-themes.md}
            touch $out
          '';
    };
}
