#!/usr/bin/env python3
"""
Citron Configuration Manager

Manages ~/.config/citron/qt-config.ini by merging Nix-declared settings
with existing user configuration. Only updates explicitly set values.

Usage:
    citron-config <settings_json>

Where settings_json is a JSON object with the settings to apply.
Settings with null values are skipped (user's value preserved).
"""

import configparser
import json
import os
import sys
from pathlib import Path


# Value mappings from Nix enum strings to INI integer values
MAPPINGS = {
    "backend": {"opengl": 0, "vulkan": 1},
    "vsync": {"off": 0, "mailbox": 1, "fifo": 2},
    "fullscreenMode": {"borderless": 0, "exclusive": 1},
    "scalingFilter": {
        "nearest": 0,
        "bilinear": 1,
        "bicubic": 2,
        "lanczos": 3,
        "gaussian": 4,
        "scaleforce": 5,
        "scalefx": 6,
        "fsr": 7,
        "fsr2": 8,
    },
    "gpuAccuracy": {"normal": 0, "high": 1, "extreme": 2},
    "language": {
        "japanese": 0,
        "english": 1,
        "french": 2,
        "german": 3,
        "italian": 4,
        "spanish": 5,
        "chinese": 6,
        "korean": 7,
        "dutch": 8,
        "portuguese": 9,
        "russian": 10,
        "taiwanese": 11,
        "british-english": 12,
    },
    "region": {
        "japan": 0,
        "usa": 1,
        "europe": 2,
        "australia": 3,
        "china": 4,
        "korea": 5,
        "taiwan": 6,
    },
    "theme": {
        "default": "default",
        "colorful": "colorful",
        "colorful_dark": "colorful_dark",
        "colorful_midnight_blue": "colorful_midnight_blue",
        "qdarkstyle": "qdarkstyle",
        "qdarkstyle_midnight_blue": "qdarkstyle_midnight_blue",
    },
}

# Map from our setting names to INI keys
# Format: (section, key)
INI_KEYS = {
    # Graphics
    "backend": ("Renderer", "backend"),
    "resolution": ("Renderer", "resolution_setup"),
    "vsync": ("Renderer", "use_vsync"),
    "fullscreenMode": ("Renderer", "fullscreen_mode"),
    "scalingFilter": ("Renderer", "scaling_filter"),
    "gpuAccuracy": ("Renderer", "gpu_accuracy"),
    "asyncShaders": ("Renderer", "use_asynchronous_shaders"),
    "diskShaderCache": ("Renderer", "use_disk_shader_cache"),
    # System
    "dockedMode": ("System", "use_docked_mode"),
    "language": ("System", "language_index"),
    "region": ("System", "region_index"),
    # Performance
    "multicore": ("Core", "use_multi_core"),
    "speedLimit": ("Core", "speed_limit"),
    # Audio
    "volume": ("Audio", "volume"),
    "muteInBackground": ("Audio", "muteWhenInBackground"),
    # UI
    "fullscreen": ("UI", "fullscreen"),
    "confirmStop": ("UI", "confirmStop"),
    "pauseInBackground": ("UI", "pauseWhenInBackground"),
    "theme": ("UI", "theme"),
}


def convert_value(key: str, value):
    """Convert a Nix value to INI value using mappings."""
    if value is None:
        return None

    # Check if we have a mapping for this key
    if key in MAPPINGS:
        mapping = MAPPINGS[key]
        if value in mapping:
            return mapping[value]
        # If not in mapping, assume it's already the right type
        return value

    # Boolean to string
    if isinstance(value, bool):
        return "true" if value else "false"

    # Resolution: 1:1 mapping from multiplier to INI index
    # User writes the actual multiplier they want (0.5, 1, 2, 4, etc.)
    if key == "resolution":
        resolution_map = {
            0.5: 0,
            0.75: 1,
            1: 2,
            1.5: 3,
            2: 4,
            3: 5,
            4: 6,
            5: 7,
            6: 8,
            7: 9,
            8: 10,
        }
        # Handle both int and float (e.g., 2 and 2.0)
        lookup = float(value)
        if lookup in resolution_map:
            return resolution_map[lookup]
        # Try as int for whole numbers
        if lookup == int(lookup) and int(lookup) in resolution_map:
            return resolution_map[int(lookup)]
        print(
            f"Warning: Invalid resolution {value}, valid values: {list(resolution_map.keys())}",
            file=sys.stderr,
        )
        return None

    # Integers and strings pass through
    return value


class CaseSensitiveConfigParser(configparser.ConfigParser):
    """ConfigParser that preserves key case."""

    def optionxform(self, optionstr: str) -> str:
        return optionstr


def read_config(path: Path) -> configparser.ConfigParser:
    """Read existing config or create empty one."""
    config = CaseSensitiveConfigParser()

    if path.exists():
        # Read with UTF-8 encoding
        with open(path, "r", encoding="utf-8") as f:
            config.read_file(f)

    return config


def write_config(config: configparser.ConfigParser, path: Path):
    """Write config back to file."""
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        config.write(f)


def apply_settings(config: configparser.ConfigParser, settings: dict):
    """Apply settings to config, only updating non-null values."""
    for key, value in settings.items():
        if value is None:
            continue

        if key == "gameDirectories":
            apply_game_directories(config, value)
            continue

        if key not in INI_KEYS:
            print(f"Warning: Unknown setting '{key}', skipping", file=sys.stderr)
            continue

        section, ini_key = INI_KEYS[key]
        converted = convert_value(key, value)

        if converted is None:
            continue

        # Ensure section exists
        if section not in config:
            config[section] = {}

        # Set value and mark as non-default
        config[section][ini_key] = str(converted)
        config[section][f"{ini_key}\\default"] = "false"

        print(f"Set [{section}] {ini_key} = {converted}")


def apply_game_directories(config: configparser.ConfigParser, directories: list):
    """Append game directories to existing list."""
    if not directories:
        return

    section = "UI"
    if section not in config:
        config[section] = {}

    # Find existing game directories count
    size_key = "Paths\\gamedirs\\size"
    existing_size = int(config[section].get(size_key, "0"))

    # Get existing paths to avoid duplicates
    existing_paths = set()
    for i in range(1, existing_size + 1):
        path_key = f"Paths\\gamedirs\\{i}\\path"
        if path_key in config[section]:
            existing_paths.add(config[section][path_key])

    # Add new directories
    added = 0
    for directory in directories:
        if directory in existing_paths:
            print(f"Game directory already exists: {directory}")
            continue

        idx = existing_size + added + 1
        config[section][f"Paths\\gamedirs\\{idx}\\path"] = directory
        config[section][f"Paths\\gamedirs\\{idx}\\deep_scan\\default"] = "true"
        config[section][f"Paths\\gamedirs\\{idx}\\deep_scan"] = "false"
        config[section][f"Paths\\gamedirs\\{idx}\\expanded\\default"] = "true"
        config[section][f"Paths\\gamedirs\\{idx}\\expanded"] = "true"
        added += 1
        print(f"Added game directory: {directory}")

    # Update size
    if added > 0:
        config[section][size_key] = str(existing_size + added)


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <settings_json>", file=sys.stderr)
        sys.exit(1)

    # Parse settings JSON
    try:
        settings = json.loads(sys.argv[1])
    except json.JSONDecodeError as e:
        print(f"Error parsing settings JSON: {e}", file=sys.stderr)
        sys.exit(1)

    # Config file path
    config_path = Path.home() / ".config" / "citron" / "qt-config.ini"

    print(f"Managing Citron config: {config_path}")

    # Read existing config
    config = read_config(config_path)

    # Apply settings
    apply_settings(config, settings)

    # Write back
    write_config(config, config_path)

    print("Citron configuration updated successfully")


if __name__ == "__main__":
    main()
