#!/usr/bin/env python3
"""
Steam Preferences Patcher

This script patches Steam's VDF files to set preferences declaratively:
- localconfig.vdf: Friends/chat settings, remote play
- config.vdf: Default compatibility tool (Proton)

It uses atomic writes and creates backups to ensure safe modifications.
"""

import sys
import json
import os
import shutil
from pathlib import Path
from typing import Dict, Any, Optional
import vdf


# Mapping from JSON settings to VDF keys (for friends settings)
SETTINGS_MAP = {
    "autoSignIn": "AutoSignIntoFriends",
    "showIngame": "Notifications_ShowIngame",
    "showOnline": "Notifications_ShowOnline",
    "showMessage": "Notifications_ShowMessage",
    "playIngame": "Sounds_PlayIngame",
    "playOnline": "Sounds_PlayOnline",
    "playMessage": "Sounds_PlayMessage",
}

# Additional settings that don't map directly to friends section
EXTRA_SETTINGS = {
    "enableStreaming",
    "defaultCompatTool",
    "guideButtonFocusesSteam",
    "disableShaderCache",
    "enableShaderBackgroundProcessing",
}


def get_steam_path() -> Path:
    """Get the path to the Steam directory."""
    return Path.home() / ".steam" / "steam"


def get_localconfig_path(steamid: str) -> Path:
    """Get the path to the localconfig.vdf file for the given Steam ID."""
    return get_steam_path() / "userdata" / steamid / "config" / "localconfig.vdf"


def get_config_path() -> Path:
    """Get the path to the global config.vdf file."""
    return get_steam_path() / "config" / "config.vdf"


def create_backup(vdf_path: Path) -> None:
    """Create a backup of the VDF file if one doesn't exist."""
    backup_path = vdf_path.with_suffix(".vdf.bak")
    if not backup_path.exists() and vdf_path.exists():
        shutil.copy2(vdf_path, backup_path)
        print(f"Created backup: {backup_path}")


def load_vdf(vdf_path: Path) -> Optional[Dict[str, Any]]:
    """Load and parse the VDF file. Returns None if file doesn't exist or is malformed."""
    if not vdf_path.exists():
        return None

    try:
        with open(vdf_path, "r", encoding="utf-8") as f:
            return vdf.load(f)
    except Exception as e:
        print(f"Warning: Failed to parse VDF file: {e}", file=sys.stderr)
        # Create backup of malformed file
        malformed_backup = vdf_path.with_suffix(".vdf.malformed")
        shutil.copy2(vdf_path, malformed_backup)
        print(f"Backed up malformed file to: {malformed_backup}")
        return None


def create_default_vdf() -> Dict[str, Any]:
    """Create a minimal default VDF structure with friends settings."""
    return {"UserLocalConfigStore": {"friends": {}}}


def patch_friends_settings(
    data: Dict[str, Any], settings: Dict[str, str], steamid: str
) -> Dict[str, Any]:
    """Patch the friends section with new settings, preserving other data."""
    # Ensure the structure exists
    if "UserLocalConfigStore" not in data:
        data["UserLocalConfigStore"] = {}

    if "friends" not in data["UserLocalConfigStore"]:
        data["UserLocalConfigStore"]["friends"] = {}

    friends_section = data["UserLocalConfigStore"]["friends"]

    # Apply legacy settings (may still be read by some Steam versions)
    for json_key, vdf_key in SETTINGS_MAP.items():
        if json_key in settings:
            value = settings[json_key]
            # Ensure value is a string "0" or "1"
            if isinstance(value, bool):
                value = "1" if value else "0"
            elif isinstance(value, int):
                value = str(value)
            friends_section[vdf_key] = value
            print(f"  {vdf_key} = {value}")

    # Patch JSON-formatted settings in BOTH friends and WebStorage sections
    # Steam reads from WebStorage, but we patch both for compatibility
    prefs_key = f"FriendStoreLocalPrefs_{steamid}"
    popup_key = f"ChatStorePopupState_{steamid}"

    # Get WebStorage section (where Steam actually reads from)
    if "WebStorage" not in data["UserLocalConfigStore"]:
        data["UserLocalConfigStore"]["WebStorage"] = {}
    web_storage = data["UserLocalConfigStore"]["WebStorage"]

    # Patch both sections
    for section_name, section in [
        ("friends", friends_section),
        ("WebStorage", web_storage),
    ]:
        # FriendStoreLocalPrefs contains ePersonaState
        if prefs_key in section:
            try:
                prefs = json.loads(section[prefs_key])
            except json.JSONDecodeError:
                prefs = {}
        else:
            prefs = {}

        if "autoSignIn" in settings:
            persona_state = 1 if settings["autoSignIn"] in ("1", "online", True) else 0
            prefs["ePersonaState"] = persona_state
            if section_name == "WebStorage":
                print(
                    f"  ePersonaState = {persona_state} ({'Online' if persona_state else 'Offline'})"
                )

        section[prefs_key] = json.dumps(prefs, separators=(",", ":"))

        # ChatStorePopupState controls friends list visibility
        if popup_key in section:
            try:
                popup = json.loads(section[popup_key])
            except json.JSONDecodeError:
                popup = {}
        else:
            popup = {}

        if "autoSignIn" in settings:
            show_friends = settings["autoSignIn"] in ("1", "online", True)
            popup["bFriendsListVisible"] = show_friends
            if section_name == "WebStorage":
                print(f"  bFriendsListVisible = {show_friends}")

        section[popup_key] = json.dumps(popup, separators=(",", ":"))

    return data


def patch_streaming_settings(
    data: Dict[str, Any], settings: Dict[str, Any]
) -> Dict[str, Any]:
    """Patch the streaming_v2 section for Remote Play settings."""
    if "enableStreaming" not in settings:
        return data

    # Ensure structure exists
    if "UserLocalConfigStore" not in data:
        data["UserLocalConfigStore"] = {}

    if "streaming_v2" not in data["UserLocalConfigStore"]:
        data["UserLocalConfigStore"]["streaming_v2"] = {}

    streaming = data["UserLocalConfigStore"]["streaming_v2"]

    value = settings["enableStreaming"]
    if isinstance(value, bool):
        value = "1" if value else "0"
    elif isinstance(value, int):
        value = str(value)

    streaming["EnableStreaming"] = value
    print(f"  EnableStreaming = {value} ({'Enabled' if value == '1' else 'Disabled'})")

    return data


def patch_controller_settings(
    data: Dict[str, Any], settings: Dict[str, Any]
) -> Dict[str, Any]:
    """Patch controller settings at root of UserLocalConfigStore."""
    if "guideButtonFocusesSteam" not in settings:
        return data

    # Ensure structure exists
    if "UserLocalConfigStore" not in data:
        data["UserLocalConfigStore"] = {}

    value = settings["guideButtonFocusesSteam"]
    if isinstance(value, bool):
        value = "1" if value else "0"
    elif isinstance(value, int):
        value = str(value)

    data["UserLocalConfigStore"]["Controller_CheckGuideButton"] = value
    print(
        f"  Controller_CheckGuideButton = {value} ({'Enabled' if value == '1' else 'Disabled'})"
    )

    return data


def patch_compat_tool(config_path: Path, settings: Dict[str, Any]) -> bool:
    """Patch the config.vdf for default compatibility tool. Returns True if patched."""
    if "defaultCompatTool" not in settings or settings["defaultCompatTool"] is None:
        return False

    tool_name = settings["defaultCompatTool"]

    if not config_path.exists():
        print(f"  config.vdf not found at {config_path}, skipping compat tool")
        return False

    # Load config.vdf
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = vdf.load(f)
    except Exception as e:
        print(f"  Warning: Failed to parse config.vdf: {e}", file=sys.stderr)
        return False

    # Create backup
    create_backup(config_path)

    # Navigate to CompatToolMapping
    # Path: InstallConfigStore -> Software -> Valve -> Steam -> CompatToolMapping
    try:
        steam_section = data["InstallConfigStore"]["Software"]["Valve"]["Steam"]
    except KeyError:
        print("  Warning: Could not find Steam section in config.vdf", file=sys.stderr)
        return False

    if "CompatToolMapping" not in steam_section:
        steam_section["CompatToolMapping"] = {}

    compat_mapping = steam_section["CompatToolMapping"]

    # "0" is the default for all games
    if "0" not in compat_mapping:
        compat_mapping["0"] = {}

    compat_mapping["0"]["name"] = tool_name
    compat_mapping["0"]["config"] = ""
    compat_mapping["0"]["priority"] = "75"

    print(f"  Default compatibility tool = {tool_name}")

    # Write atomically
    atomic_write_vdf(config_path, data)
    return True


def patch_shader_cache(config_path: Path, settings: Dict[str, Any]) -> bool:
    """Patch the config.vdf for shader cache settings. Returns True if patched."""
    has_disable = "disableShaderCache" in settings
    has_background = "enableShaderBackgroundProcessing" in settings

    if not has_disable and not has_background:
        return False

    if not config_path.exists():
        print(
            f"  config.vdf not found at {config_path}, skipping shader cache settings"
        )
        return False

    # Load config.vdf
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            data = vdf.load(f)
    except Exception as e:
        print(f"  Warning: Failed to parse config.vdf: {e}", file=sys.stderr)
        return False

    # Create backup
    create_backup(config_path)

    # Navigate to ShaderCacheManager
    # Path: InstallConfigStore -> Software -> Valve -> Steam -> ShaderCacheManager
    try:
        steam_section = data["InstallConfigStore"]["Software"]["Valve"]["Steam"]
    except KeyError:
        print("  Warning: Could not find Steam section in config.vdf", file=sys.stderr)
        return False

    if "ShaderCacheManager" not in steam_section:
        steam_section["ShaderCacheManager"] = {}

    shader_manager = steam_section["ShaderCacheManager"]

    if has_disable:
        value = settings["disableShaderCache"]
        if isinstance(value, bool):
            value = "1" if value else "0"
        elif isinstance(value, int):
            value = str(value)
        shader_manager["DisableShaderCache"] = value
        status = "Disabled" if value == "1" else "Enabled"
        print(f"  Shader Pre-Caching = {status}")

    if has_background:
        value = settings["enableShaderBackgroundProcessing"]
        if isinstance(value, bool):
            value = "1" if value else "0"
        elif isinstance(value, int):
            value = str(value)
        shader_manager["EnableShaderBackgroundProcessing"] = value
        status = "Enabled" if value == "1" else "Disabled"
        print(f"  Background Vulkan Shader Processing = {status}")

    # Write atomically
    atomic_write_vdf(config_path, data)
    return True


def atomic_write_vdf(vdf_path: Path, data: Dict[str, Any]) -> None:
    """Write VDF data atomically using temp file + rename."""
    temp_path = vdf_path.with_suffix(".vdf.tmp")

    try:
        with open(temp_path, "w", encoding="utf-8") as f:
            vdf.dump(data, f, pretty=True)

        # Atomic rename
        temp_path.replace(vdf_path)
        print(f"Successfully wrote: {vdf_path}")
    except Exception as e:
        # Clean up temp file on failure
        if temp_path.exists():
            temp_path.unlink()
        raise e


def main() -> int:
    """Main entry point."""
    if len(sys.argv) != 3:
        print("Usage: steam-prefs.py <steamid> <json-settings>", file=sys.stderr)
        print("", file=sys.stderr)
        print("Example:", file=sys.stderr)
        print(
            '  steam-prefs.py 123456789 \'{"autoSignIn":"0","enableStreaming":"1","defaultCompatTool":"GE-Proton"}\'',
            file=sys.stderr,
        )
        return 1

    steamid = sys.argv[1]

    try:
        settings = json.loads(sys.argv[2])
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON settings: {e}", file=sys.stderr)
        return 1

    # Validate settings keys
    valid_keys = set(SETTINGS_MAP.keys()) | EXTRA_SETTINGS
    invalid_keys = set(settings.keys()) - valid_keys
    if invalid_keys:
        print(f"Warning: Unknown settings keys: {invalid_keys}", file=sys.stderr)

    localconfig_path = get_localconfig_path(steamid)
    config_path = get_config_path()

    # Check if Steam has been run yet
    if not localconfig_path.parent.exists():
        print(f"Steam userdata directory not found: {localconfig_path.parent}")
        print("This is normal if Steam hasn't been run yet. Exiting gracefully.")
        return 0

    print(f"Patching Steam preferences for user {steamid}")

    # Load existing localconfig.vdf or create default
    data = load_vdf(localconfig_path)
    if data is None:
        print("Creating fresh VDF structure")
        data = create_default_vdf()
    else:
        # Create backup on first modification
        create_backup(localconfig_path)

    # Patch settings in localconfig.vdf
    print("Applying settings to localconfig.vdf:")
    data = patch_friends_settings(data, settings, steamid)
    data = patch_streaming_settings(data, settings)
    data = patch_controller_settings(data, settings)

    # Write localconfig.vdf atomically
    atomic_write_vdf(localconfig_path, data)

    # Patch config.vdf for compatibility tool (separate file)
    if "defaultCompatTool" in settings and settings["defaultCompatTool"] is not None:
        print("Applying settings to config.vdf:")
        patch_compat_tool(config_path, settings)

    # Patch config.vdf for shader cache settings
    if (
        "disableShaderCache" in settings
        or "enableShaderBackgroundProcessing" in settings
    ):
        print("Applying shader cache settings to config.vdf:")
        patch_shader_cache(config_path, settings)

    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        print("\nInterrupted", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        import traceback

        traceback.print_exc()
        sys.exit(1)
