# Mountainous Rethink

A NixOS configuration flake for managing multiple system configurations with integrated home-manager support.

## Overview

This repository contains a NixOS configuration flake that makes it easy to manage multiple system configurations across different architectures. The project is structured to allow for:

- Organizing configurations by architecture and system name
- Building and testing configurations in VMs
- Deploying configurations to physical machines
- Consistent home-manager configurations across systems with per-system customization

## Getting Started

### Prerequisites

- [Nix](https://nixos.org/download.html) with flakes enabled

### Using This Repository

1. Clone the repository:
   ```
   git clone <repository-url>
   cd mountainous-rethink
   ```

2. Build a VM for testing:
   ```
   nix build .#vm-fuji
   ```

3. Run the VM:
   ```
   ./result/bin/run-nixos-vm
   ```

## Project Structure

```
├── flake.nix              # Main flake entry point
├── flake.lock             # Dependency lock file
├── utils.nix              # Helper functions for the flake
├── home/                  # Default home-manager configurations
│   └── default.nix        # Applied to all systems
├── modules/               # Reusable modules
│   ├── home/              # Home-manager modules
│   │   └── my-home-manager-module/
│   │       └── default.nix
│   └── nixos/             # NixOS modules
│       └── my-nixos-module/
│           └── default.nix
├── systems/               # System configurations by architecture
│   └── x86_64-linux/      # x86_64 Linux configurations
│       └── fuji/          # Example system named "fuji"
│           ├── default.nix # System configuration
│           └── home.nix    # System-specific home-manager configuration
```

## Adding a New System

1. Create a new directory under the appropriate architecture in `systems/`:
   ```
   mkdir -p systems/x86_64-linux/new-system
   ```

2. Create a `default.nix` file with your system configuration:
   ```nix
   {
     config,
     pkgs,
     ...
   }: {
     # Your system configuration here
     # See the fuji example for reference
   }
   ```

3. Optionally add a `home.nix` file with system-specific home-manager configuration:
   ```nix
   { config, pkgs, ... }: {
     # System-specific home-manager configuration
     # This will be merged with the default configuration
     home.packages = with pkgs; [
       # Additional packages for this system
     ];
   }
   ```

4. Build and test the new configuration:
   ```
   nix build .#vm-new-system
   ./result/bin/run-nixos-vm
   ```

## Deploying to Hardware

To deploy to a physical machine:

```
sudo nixos-rebuild switch --flake .#your-system-name
```

## Default User

The default configuration creates a user with:
- Username: `nixos`
- Password: `changeme` (change this immediately after first login)
- Admin privileges (part of the wheel group)
- Home-manager configuration from `home/default.nix` and any system-specific `home.nix`

### Home Manager Configuration

The system uses a three-layer approach for home-manager configurations:

1. **Modules** (`/modules/home/*/default.nix`): Reusable modules that are automatically loaded on all systems
2. **Default configuration** (`/home/default.nix`): Applied to all systems, providing a consistent base
3. **System-specific configuration** (`/systems/<arch>/<name>/home.nix`): Merged on top of the default configuration

If any of these files don't exist, the system will work fine without them. This approach allows you to:
- Create reusable modules for specific functionality
- Maintain consistent configuration across all systems
- Customize per-system where needed
- Add or remove any layer without breaking anything

### NixOS Modules

Similar to home-manager, NixOS modules are automatically loaded:

1. **Modules** (`/modules/nixos/*/default.nix`): Reusable modules that are automatically loaded on all systems
2. **System configuration** (`/systems/<arch>/<name>/default.nix`): System-specific configuration

These modules can be enabled in the system configuration files as needed.

## License

MIT