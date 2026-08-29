# Direct Nix commands

Mountainous uses direct Nix and NixOS commands for routine rebuilds. The destructive fresh-install app and specialized Sobo script remain separate.

## NixOS hosts

Run local commands from the repository checkout on the target host.

```bash
# Evaluate and build the candidate with live build logs.
nix build .#nixosConfigurations.<host>.config.system.build.toplevel -L

# Review package changes before activation.
nix store diff-closures /run/current-system ./result

# Activate the candidate without making it the boot default.
sudo ./result/bin/switch-to-configuration test

# Build, register, and persist the configuration.
sudo nixos-rebuild switch --flake .#<host>
```

Use the other standard activation modes when needed.

```bash
sudo nixos-rebuild test --flake .#<host>
sudo nixos-rebuild boot --flake .#<host>
nixos-rebuild build --flake .#<host>
```

For remote deployment, state the build and target hosts explicitly.

```bash
NIX_SSHOPTS="-F /dev/null" nixos-rebuild switch \
  --flake .#<host> \
  --build-host <build-host> \
  --target-host <user@target-host> \
  --sudo
```

Use the specialized script for Sobo input overrides. It pins port `2222`, verifies the checked-in host key, builds on Fuji, and activates through the `simonwjackson` wheel user.

```bash
NIX_ON_ROCKS_GUEST=/path/to/nix-on-rocks/guest \
KORRI=/path/to/korri \
./switch-sobo-overrides.sh
```

## Nix-on-Droid

Run activation from an existing repository checkout on the device.

```bash
nix-on-droid switch --flake .#usu
```

To deploy from another host, copy only committed files into a clean deployment directory. Usu exposes SSH on port `2345` as `nix-on-droid`.

```bash
ssh -F /dev/null -p 2345 nix-on-droid@usu 'rm -rf ~/mountainous && mkdir -p ~/mountainous'
git ls-files -z | rsync -av --from0 --files-from=- \
  --rsync-path=/etc/profiles/per-user/nix-on-droid/bin/rsync \
  -e 'ssh -F /dev/null -p 2345' \
  ./ nix-on-droid@usu:~/mountainous/
ssh -F /dev/null -p 2345 nix-on-droid@usu \
  'cd ~/mountainous && /etc/profiles/per-user/nix-on-droid/bin/nix-on-droid switch --flake .#usu'
```

## Repository maintenance

```bash
nix flake update
nix flake update <input>
git ls-files -z '*.nix' | xargs -0 nix fmt --
nix develop
nix repl -f flake:nixpkgs
nix profile history --profile /nix/var/nix/profiles/system
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d
sudo nix-collect-garbage --delete-old
nix run .#syncthing-keygen -- <host>
```

## Secrets

```bash
nix run .#secrets -- encrypt --help
nix run .#secrets -- rekey
```

## Host setup

```bash
nix run .#scaffold -- <host>
```

Fresh installation is destructive. Scaffold the host before deployment.

```bash
nix run .#scaffold -- <host>
nix run .#deploy -- <host> <user@target>
```
