- **CRITICAL**: Always `git add` new files immediately - Nix flakes only see git-tracked files
- **External Dependencies**: Prefer flake inputs with `flake = false` over `fetchurl`/`fetchFromGitHub` for updatability via `nix flake update`
- Enable features with `mountainous.features.<name>.enable = true`
- Use direct `nix`, `nixos-rebuild`, and `nix-on-droid` commands. See `docs/nix-commands.md`.
- `hyprctl --instance 0 ..` for all hyprctl commands
- `nix run .#deploy` - **DESTRUCTIVE** - For fresh system installs only. Will wipe the target system.
- Run tests before completing any task, adding or updating tests as needed
- use ssh -F /dev/null when connecting

## Extending Upstream NixOS Modules

When wrapping an upstream module (e.g., `services.sunshine`) with custom options:

1. **Add custom options** to your module, then **forward to upstream** in `config`:
   ```nix
   options.mountainous.foo = {
     myOption = mkOption { ... };  # Your custom option
   };
   config = mkIf cfg.enable {
     services.foo = {               # Forward to upstream
       enable = true;
       setting = cfg.myOption;
     };
   };
   ```

2. **Don't redeclare upstream options** - set them directly via `services.*` in `config`

3. **Use `mkDefault`** for values that systems might override
