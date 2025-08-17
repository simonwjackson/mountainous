# Mountainous Syncthing Module

A declarative NixOS module for managing Syncthing configurations across multiple systems with auto-discovery and advanced features.

## Features

### 🔍 Auto-Discovery System
- Automatically discovers all systems with `syncthing.nix` configuration files
- Builds device network based on shared folder participation
- No manual device ID configuration needed

### 📁 Declarative Share Management
- Define shares once in `syncthing.nix` per system
- Automatic folder synchronization configuration
- Support for custom paths and versioning

### 🚫 Advanced .stignore Generation
- Automatic `.stignore` file creation from patterns
- Support for both whitelist and blacklist modes
- Mutual exclusivity enforcement

### 📱 External Device Support
- Easy configuration for phones, tablets, and non-NixOS systems
- Manual device ID specification
- Flexible address configuration

### 🔐 Integrated Secrets Management
- Automatic certificate configuration via agenix
- Per-system secret paths
- Secure key management

## Usage

### 1. Enable the Module

In your system configuration:

```nix
{
  mountainous.syncthing = {
    enable = true;
    user = "simonwjackson";  # optional, defaults to mountainous.user.name
    
    # Optional: Configure external devices
    otherDevices = {
      "phone" = {
        id = "DEVICE-ID-HERE";
        shares = ["photos" "documents"];
      };
      "tablet" = {
        id = "ANOTHER-DEVICE-ID";
        shares = ["documents"];
        addresses = ["192.168.1.100:22000"];
      };
    };
  };
}
```

### 2. Create System Configuration

Create a `syncthing.nix` file in your system directory (e.g., `nix/systems/x86_64-linux/hostname/syncthing.nix`):

```nix
{
  # Device ID (can be "AUTO-FROM-CERT" to use certificate)
  deviceId = "AUTO-FROM-CERT";
  
  # Shares this system participates in
  shares = {
    "documents" = {
      path = "/home/user/Documents";
      blacklist = [
        "*.tmp"
        "*.log"
        ".DS_Store"
        "node_modules"
      ];
      versioning = {
        type = "simple";
        params.keep = "10";
      };
    };
    
    "photos" = {
      path = "/home/user/Pictures";
      whitelist = [
        "*.jpg"
        "*.png"
        "*.raw"
      ];
    };
  };
}
```

### 3. Pattern Modes

#### Whitelist Mode
Only sync files matching the specified patterns:

```nix
"share-name" = {
  path = "/path/to/folder";
  whitelist = [
    "*.jpg"
    "*.png"
    "documents/**"
  ];
};
```

This creates a `.stignore` file that ignores everything except the whitelisted patterns.

#### Blacklist Mode
Sync everything except files matching the patterns:

```nix
"share-name" = {
  path = "/path/to/folder";
  blacklist = [
    "*.tmp"
    "*.log"
    "node_modules"
    ".git"
  ];
};
```

**Note:** You cannot use both whitelist and blacklist in the same share.

## Module Options

### Core Options

- `mountainous.syncthing.enable` - Enable the module
- `mountainous.syncthing.user` - User to run Syncthing as
- `mountainous.syncthing.group` - Group to run Syncthing as
- `mountainous.syncthing.dataDir` - Syncthing data directory
- `mountainous.syncthing.configDir` - Syncthing configuration directory

### Network Options

- `mountainous.syncthing.openDefaultPorts` - Open firewall ports (default: true)
- `mountainous.syncthing.guiAddress` - GUI listen address (default: "127.0.0.1:8384")

### Advanced Options

- `mountainous.syncthing.otherDevices` - External device configurations
- `mountainous.syncthing.secretsBasePath` - Base path for agenix secrets
- `mountainous.syncthing.disableDefaultFolder` - Disable default Syncthing folder

## Auto-Discovery

The module automatically:

1. **Scans** all systems in `nix/systems/*` for `syncthing.nix` files
2. **Extracts** device configurations and share definitions
3. **Builds** device network based on shared folder participation
4. **Configures** Syncthing with discovered devices and folders
5. **Creates** `.stignore` files from patterns
6. **Sets up** certificates from agenix secrets

## Integration with Agenix

The module automatically integrates with the mountainous agenix module:

- Expects secrets named `{hostname}-syncthing-cert` and `{hostname}-syncthing-key`
- Automatically creates symlinks in Syncthing config directory
- Handles permissions and ownership

## Example Network

With these system configurations:

**System A** (`aka/syncthing.nix`):
```nix
{
  shares = {
    "documents" = { /* config */ };
    "media" = { /* config */ };
  };
}
```

**System B** (`fuji/syncthing.nix`):
```nix
{
  shares = {
    "documents" = { /* config */ };
    "photos" = { /* config */ };
  };
}
```

**System C** (external device):
```nix
otherDevices = {
  "phone" = {
    id = "PHONE-ID";
    shares = ["photos"];
  };
};
```

The module automatically creates:
- `documents` share: synchronized between A and B
- `media` share: only on A
- `photos` share: synchronized between B and phone

## Troubleshooting

### Device Not Appearing
- Check that `syncthing.nix` exists in the system directory
- Verify the share names match between systems
- Ensure proper deviceId configuration

### Certificate Issues
- Verify agenix secrets exist for the hostname
- Check file permissions on certificate files
- Ensure mountainous.agenix.enable = true

### Share Sync Issues
- Verify folder paths exist
- Check .stignore patterns for conflicts
- Review Syncthing logs for errors

## File Structure

```
nix/
├── modules/nixos/syncthing/default.nix  # Main module
└── systems/
    └── x86_64-linux/
        ├── system1/
        │   ├── default.nix
        │   └── syncthing.nix            # System config
        └── system2/
            ├── default.nix
            └── syncthing.nix            # System config
```