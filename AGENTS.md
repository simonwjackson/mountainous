- **CRITICAL: Never run `nix flake check` in this project.** This includes flags such as `--no-build`, `--all-systems`, or `--keep-going`, global Nix options before `flake check`, and invoking it through scripts, wrappers, CI, remote commands, or durable/background processes. Concurrent checks exhausted Zao's RAM and swap and made the machine unresponsive. Do not recreate or restart saved commands that run it.
- Validate changes with focused tests and evaluation/builds of individual relevant attributes. Do not replace `nix flake check` with an aggregate build of every check. Keep validation resource usage bounded.

# mountainous

Only rules that the code cannot show are here. Read the tree and the code for everything else.

- Nix flakes see only files that git tracks. Run `git add` on each new file before you evaluate or build.
- `nix run .#install` wipes every disk of the target host and installs from scratch. Run it only for a new install that the operator approved. Change a running host with `nixos-rebuild`.
- A host file in `modules/hosts/` holds only what is unique to that machine. Put a setting that two hosts share in a layer, with `lib.mkDefault` where a host may differ. `checks.baseline` lists the allowed exceptions.
- Take external sources as flake inputs, with `flake = false` for non-flakes, so `nix flake update` moves them. Do not use `fetchurl` or `fetchFromGitHub`.
- To wrap an upstream NixOS module, declare only the new options under `mountainous.*`. Set the upstream options directly in `config`, with `lib.mkDefault` for values a host can override.
- Connect to fleet machines with `ssh -F /dev/null`.
- Run every `hyprctl` command as `hyprctl --instance 0`.
