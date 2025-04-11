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
├── packages/              # Reusable packages
│   └── ex/                # Example package
│       ├── default.nix    # Package definition
│       └── ex.sh          # Package source
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

#### Module Auto-loading

All modules placed in the `modules/home/` directory are automatically imported into every user's home-manager configuration. To add a new module:

1. Create a new directory in `modules/home/your-module-name/`
2. Add a `default.nix` file with your module definition
3. The module will be automatically loaded for all systems

To use the module, enable it in your home-manager configuration:

```nix
# In home/default.nix or systems/<arch>/<name>/home.nix
{ config, pkgs, ... }: {
  modules.your-module-name.enable = true;
}
```

### NixOS Modules

Similar to home-manager, NixOS modules are automatically loaded:

1. **Modules** (`/modules/nixos/*/default.nix`): Reusable modules that are automatically loaded on all systems
2. **System configuration** (`/systems/<arch>/<name>/default.nix`): System-specific configuration

#### Module Auto-loading

All modules placed in the `modules/nixos/` directory are automatically imported into every system configuration. To add a new module:

1. Create a new directory in `modules/nixos/your-module-name/`
2. Add a `default.nix` file with your module definition
3. The module will be automatically loaded for all systems

To use the module, enable it in your system configuration:

```nix
# In systems/<arch>/<name>/default.nix
{ config, pkgs, ... }: {
  modules.your-module-name.enable = true;
}
```

These modules can be enabled in the system configuration files as needed.

## VM Display Auto-Resizing

The system includes a module for auto-resizing VM displays when running as a QEMU virtual machine. This ensures that the internal monitor of your VM resizes to match the emulation window size.

To enable VM display auto-resizing for a system, add to your configuration:

```nix
# In systems/<arch>/<name>/default.nix
{ config, pkgs, ... }: {
  mountainous.vm-display-resize.enable = true;
}
```

The module only applies when building a VM using `nixos-rebuild build-vm` and running it with `./result/bin/run-nixos-vm`. It does not affect the system when installed on real hardware.

## Custom Packages

The flake automatically collects and exposes packages from the `packages` directory. Each package is accessible through the flake outputs and available in your NixOS configurations.

### Package Structure

Each package should be placed in its own directory under `packages/` with at least a `default.nix` file:

```
packages/
  my-package/
    default.nix    # Package definition
    # Additional sources as needed
```

### Package Definition

A typical package definition looks like this:

```nix
{
  # Snowfall Lib provides a customized `lib` instance with access to your flake's library
  # as well as the libraries available from your flake's inputs.
  lib,
  # You also have access to your flake's inputs.
  inputs,

  # All other arguments come from NixPkgs. You can use `pkgs` to pull packages or helpers
  # programmatically or you may add the named attributes as arguments here.
  pkgs,
  stdenv,
  ...
}:

stdenv.mkDerivation {
  # Create your package
}
```

### Using Packages

The packages are automatically available:

1. **In flake outputs**: `nix build .#my-package`
2. **In NixOS configurations**: `environment.systemPackages = [ pkgs.my-package ];`
3. **In home-manager configurations**: `home.packages = [ pkgs.my-package ];`
4. **To other flakes**: When your flake is imported as an input

## License

MIT
