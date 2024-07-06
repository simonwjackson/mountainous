{
  config,
  lib,
  pkgs,
  ...
}: let
  extensionSettingsJson = builtins.toJSON {
    commands = {
      _execute_browser_action = {
        precedenceList = [
          {
            id = "{d634138d-c276-4fc8-924b-40a0ea21d284}";
            value = {
              shortcut = "Ctrl+Alt+P";
            };
            enabled = true;
          }
        ];
      };
      lock = {
        precedenceList = [
          {
            id = "{d634138d-c276-4fc8-924b-40a0ea21d284}";
            value = {
              shortcut = "";
            };
            enabled = true;
          }
        ];
      };
      toggle = {
        precedenceList = [
          {
            id = "addon@darkreader.org";
            value = {
              shortcut = "";
            };
            enabled = true;
          }
        ];
      };
      addSite = {
        precedenceList = [
          {
            id = "addon@darkreader.org";
            value = {
              shortcut = "Ctrl+Alt+D";
            };
            enabled = true;
          }
        ];
      };
    };
  };

  # FILE="$HOME/.mozilla/firefox/${config.backpacker.user.name}/extension-settings.json"
  # BUG: If a precedenceList is empty, the object wont append
  updateScript = pkgs.writeScript "update-firefox-extension-settings" ''
    #!${pkgs.stdenv.shell}
    set -euo pipefail

    FILE="$HOME/.mozilla/firefox/simonwjackson/extension-settings.json"
    TEMP_FILE=$(mktemp)

    # Ensure the directory exists
    mkdir -p "$(dirname "$FILE")"

    # If the file doesn't exist, create it with the full content
    if [ ! -f "$FILE" ]; then
      echo '${extensionSettingsJson}' > "$FILE"
      exit 0
    fi

    # Merge the existing content with our desired content
    ${pkgs.jq}/bin/jq -s '
      .[0] as $existing |
      .[1] as $new |
      $existing * $new
    ' "$FILE" <(echo '${extensionSettingsJson}') > "$TEMP_FILE"

    # Replace the original file with the merged content
    mv "$TEMP_FILE" "$FILE"
  '';
in {
  home.activation.updateFirefoxExtensionSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
    $DRY_RUN_CMD ${updateScript}
  '';
}
