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

## Zao reviewed local federation pin — build only

Zao's `korri-input-host` URL and lock pin the reviewed producer revision
`d39ea55d7e39162eaf0e175e4fa91e02d9b2feaa` through the retained local Git tag
`refs/tags/zao-federation-d39ea55d` in
`/home/simonwjackson/code/sandbox/korri`. This is a local-only pin, not remote
publication. The separate `korri` input for Aka and Sobo remains unchanged.

Keep that repository, tag and commit until an approved replacement pin is
available. Do not move/delete the tag or substitute a raw `path:` input: Git
exports the pinned tracked tree, not the producer's untracked private state.
The absolute local URL is not portable; another build machine needs the retained
repository at that path or a separately reviewed published replacement.

A normal Zao rebuild from the checkout containing this `flake.nix`/`flake.lock`
pair now consumes the pin without `--override-input`. Build and retain it with:

```bash
nix build .#nixosConfigurations.zao.config.system.build.toplevel \
  --no-write-lock-file --out-link result-federation-configured -L
```

Retain `result-federation-configured` and its `-producer-source` and
`-consumer-source` roots with the existing candidate/recovery roots. Source roots
preserve immutable exports; they do not replace local Git retention for resolving
the URL. These roots retain store data and therefore have a storage cost.

This source configuration does not activate Zao or satisfy live cutover gates.
Do not use the general activation commands above for this cutover without separate
approval. Other checkouts, including the shared main checkout, are not updated by
this worktree-only change.

## Nix-on-Droid

Run activation from an existing repository checkout on the device.

```bash
nix-on-droid switch --flake .#usu
```

To deploy from another host, extract the committed `HEAD` locally and use Usu's declared `rsync` transport. Usu exposes SSH on port `2345` as `nix-on-droid`.

```bash
deploy_dir=$(mktemp -d)
trap 'rm -rf "$deploy_dir"' EXIT
git archive HEAD | tar -xf - -C "$deploy_dir"
ssh -F /dev/null -p 2345 nix-on-droid@usu 'mkdir -p ~/mountainous'
rsync -av --delete \
  --rsync-path=/etc/profiles/per-user/nix-on-droid/bin/rsync \
  -e 'ssh -F /dev/null -p 2345' \
  "$deploy_dir/" nix-on-droid@usu:~/mountainous/
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
