# Mountainous Rethink

A NixOS configuration flake for managing multiple system configurations.

## Overview

This repository contains a NixOS configuration flake that makes it easy to manage multiple system configurations across different architectures. The project is structured to allow for:

- Organizing configurations by architecture and system name
- Building and testing configurations in VMs
- Deploying configurations to physical machines

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
├── systems/               # System configurations by architecture
│   └── x86_64-linux/      # x86_64 Linux configurations
│       └── fuji/          # Example system named "fuji"
│           └── default.nix # System configuration
```

## Adding a New System

1. Create a new directory under the appropriate architecture in `systems/`:
   ```
   mkdir -p systems/x86_64-linux/new-system
   ```

2. Create a `default.nix` file with your configuration:
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

3. Build and test the new configuration:
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

## License

MIT