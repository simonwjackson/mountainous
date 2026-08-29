# Direct Nix commands

Mountainous uses direct Nix and NixOS commands. The repository has no deployment wrapper.

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
nixos-rebuild switch \
  --flake .#<host> \
  --build-host <build-host> \
  --target-host <user@target-host> \
  --sudo
```

Pass input overrides directly to `nixos-rebuild`.

```bash
nixos-rebuild switch \
  --flake .#sobo \
  --override-input korri path:/path/to/korri \
  --override-input nix-on-rocks-guest path:/path/to/nix-on-rocks/guest \
  --build-host fuji \
  --target-host korri@sobo \
  --sudo
```

`switch-sobo-overrides.sh` keeps Sobo's checked host-key and port setup for this specialized deployment path.

## Nix-on-Droid

Build the activation package from any compatible Nix host.

```bash
nix build .#nixOnDroidConfigurations.usu.activationPackage -L
```

Run activation from an existing repository checkout on the device.

```bash
nix-on-droid switch --flake .#usu
```

To deploy from another host, copy the checkout first. This preserves the transport that the removed deployment wrapper provided.

```bash
ssh usu 'mkdir -p ~/mountainous'
rsync -av --delete --exclude .git \
  --rsync-path=/etc/profiles/per-user/nix-on-droid/bin/rsync \
  ./ usu:~/mountainous/
ssh usu 'cd ~/mountainous && /etc/profiles/per-user/nix-on-droid/bin/nix-on-droid switch --flake .#usu'
```

## Repository maintenance

```bash
nix flake update
nix flake update <input>
nix fmt .
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
