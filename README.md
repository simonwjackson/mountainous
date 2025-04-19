<h3 align="center">
    <img src="./.github/assets/mountainous-logo.jpg" width="300px"/>
</h3>
<h1 align="center">
    Mountainous 🏔️ | My <a href="https://nixos.org">NixOS</a> homelab configs.
</h1>

<div align="center">
  <a href="https://github.com/simonwjackson/neovim-nix-config">
      <img alt="Static Badge" src="https://img.shields.io/badge/Made_with-Neovim-57A143?style=for-the-badge&logo=neovim&logoColor=57A143&labelColor=161B22">
    </a>
    <img alt="Static Badge" src="https://img.shields.io/badge/NixOS-unstable-d2a8ff?style=for-the-badge&logo=NixOS&logoColor=cba6f7&labelColor=161B22">
    <img alt="Static Badge" src="https://img.shields.io/badge/State-Forever_WIP-ff7b72?style=for-the-badge&logo=fireship&logoColor=ff7b72&labelColor=161B22">
    <a href="https://github.com/simonwjackson/mountainous/pulse">
      <img alt="Last commit" src="https://img.shields.io/github/last-commit/simonwjackson/mountainous?style=for-the-badge&logo=github&logoColor=D9E0EE&labelColor=302D41&color=9fdf9f"/>
    </a>
    <img alt="Static Badge" src="https://img.shields.io/badge/Powered_by-Electrolytes-79c0ff?style=for-the-badge&logo=nuke&logoColor=79c0ff&labelColor=161B22">
    <a href="https://github.com/simonwjackson/mountainous/tree/main/LICENSE">
      <img alt="License" src="https://img.shields.io/badge/License-MIT-907385605422448742?style=for-the-badge&logo=agpl&color=DDB6F2&logoColor=D9E0EE&labelColor=302D41">
    </a>
    <a href="https://www.buymeacoffee.com/simonwjackson">
      <img alt="Buy me a coffee" src="https://img.shields.io/badge/Buy%20me%20a%20coffee-grey?style=for-the-badge&logo=buymeacoffee&logoColor=D9E0EE&label=Sponsor&labelColor=302D41&color=ffff99" />
    </a>
</div>

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
├── packages/              # Reusable packages (supports unlimited nesting)
│   └── ex/                # Example package
│       ├── default.nix    # Package definition
│       └── ex.sh          # Package source
├── modules/               # Reusable modules (supports unlimited nesting)
│   ├── home/              # Home-manager modules
│   │   └── my-home-manager-module/
│   │       └── default.nix
│   │   └── nested/        # Nested modules are supported
│   │       └── example/
│   │           └── default.nix
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

All modules placed in the `modules/home/` directory (including any nested subdirectories) are automatically imported into every user's home-manager configuration. To add a new module:

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

All modules placed in the `modules/nixos/` directory (including any nested subdirectories) are automatically imported into every system configuration. To add a new module:

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

## Impermanence

The system includes a module for impermanence, which allows for a stateless NixOS setup with persistent data stored in a separate partition.

To enable impermanence for a system, add to your configuration:

```nix
# In systems/<arch>/<name>/default.nix
{ config, pkgs, ... }: {
  mountainous.impermanence = {
    enable = true;
    persistPath = "/path/to/persist"; # Default: /persist
    persistDevice = "/dev/path/to/device"; # Required: Device to mount at persistPath
  };
}
```

The `persistDevice` option is required and should point to the device that will be mounted at the `persistPath`. This is typically a partition on your disk, such as `/dev/mapper/hostname-frostbite` when using LUKS encryption.

## VM Display Auto-Resizing

The system includes a module for auto-resizing VM displays when running as a QEMU virtual machine. This ensures that the internal monitor of your VM resizes to match the emulation window size.

To enable VM display auto-resizing for a system, add to your configuration:

```nix
# In systems/<arch>/<name>/default.nix
{ config, pkgs, ... }: {
  mountainous.vm.enable = true;
}
```

The module only applies when building a VM using `nixos-rebuild build-vm` and running it with `./result/bin/run-nixos-vm`. It does not affect the system when installed on real hardware.

## Hyprland Configuration

The mountainous configuration includes Hyprland as a window manager option with various pre-configured keybindings.

### Key Applications and Shortcuts

| Application | Shortcut | Description |
|-------------|----------|-------------|
| walker | SUPER + SPACE | Toggle application launcher |

For more details on the Hyprland configuration, see the `nix/modules/home/hyprland/default.nix` file.

## Sunshine Configuration

The Sunshine module provides game streaming capability with customizable resolution and refresh rate settings per application.

### Resolution, Refresh Rate, and Scaling Configuration

Each application entry in the Sunshine configuration can specify its own resolution, refresh rate, and scaling factor. The resolution and refresh rate are specified in the format `resolution@fps`, and scaling is an integer value (typically 1 or 2). 

For example:

```nix
{
  name = "4K 60";
  prep-cmd = [
    {
      do = makeOnConnect { resolution = "3840x2160@60"; scaling = 1; };
      undo = "";
    }
  ];
  # other configuration...
}
```

```nix
{
  name = "ZFold 6 (Landscape)";
  prep-cmd = [
    {
      do = makeOnConnect { resolution = "2160x1856@90"; scaling = 2; };
      undo = "";
    }
  ];
  # other configuration...
}
```

This allows you to have different display settings for various devices and use cases:
- For larger displays or desktop monitors, use `scaling = 1`
- For smaller and/or high-DPI displays like phones and tablets, use `scaling = 2` for better readability

The scaling parameter is optional and defaults to 1 if not specified.

Configuration is located at `nix/systems/x86_64-linux/aka/sunshine.nix`.

## Custom Packages

The flake automatically collects and exposes packages from the `packages` directory. Each package is accessible through the flake outputs and available in your NixOS configurations.

### Package Structure

Each package should be placed in its own directory under `packages/` with at least a `default.nix` file. Packages can be nested in subdirectories to any depth, and will be available with names that reflect their path (with slashes replaced by dashes):

```
packages/
  my-package/
    default.nix    # Package definition (accessible as my-package)
    # Additional sources as needed
  nested/
    cool-package/   # Nested package (accessible as nested-cool-package)
      default.nix
    deeply/
      nested/
        pkg/         # Deeply nested package (accessible as nested-deeply-nested-pkg)
          default.nix
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

Packages are made available through:

1. Adding a `collectPackages` function that scans the `packages` directory.
2. Making packages available via flake outputs (`packages.x86_64-linux.package-name`).
3. Making packages available to NixOS and home-manager via an overlay.

When adding packages to the system, they should be used as:

- In system configs: `environment.systemPackages = with pkgs; [ package-name ];`
- In home-manager: `home.packages = with pkgs; [ package-name ];`

The package name in the derivation (`name = "package-name"`) should match the directory name under `packages/`.

## Custom Overlays

You can add custom overlays to your flake by modifying the `flake.nix` file. Overlays allow you to extend or override packages in nixpkgs.

To add overlays, modify your `flake.nix` file as follows:

```nix
# In flake.nix
outputs = inputs: let
  utils = import ./utils.nix {inherit inputs;};
in
  utils.mkFlake {
    inherit inputs;
    namespace = "mountainous";
    overlays = with inputs; [
      (final: prev: {
        # Example: pulling packages from the chaotic input
        gamescope_git = chaotic.packages.${prev.system}.gamescope_git;
        gamescope-wsi_git = chaotic.packages.${prev.system}.gamescope-wsi_git;
        
        # Add more overlays as needed
      })
      # Add more overlay functions as needed
    ];
  };
```

These overlays will be applied when importing nixpkgs, making the packages available in all your configurations.

## License

MIT
