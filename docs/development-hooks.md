# Git hooks

Enter this checkout's pinned development shell before committing or pushing:

```sh
nix develop
lefthook run pre-push --no-auto-install --force
```

The shell supplies `lefthook` from `flake.lock`'s nixpkgs. It does not install
anything globally or alter Git hooks on entry. The tracked `lefthook.yml` runs
only the local-flake-input guard before a push, not aggregate Nix checks.
`checks.lefthook` runs that real runner in a temporary Git repository and proves
that local URL/lock inputs fail. It never pushes.

For a new clone, run `lefthook install` once inside the shell to install its
pre-push hook. Linked worktrees share the common Git hooks directory: install
only when the operator wants to change hooks for **all** those worktrees.
The manual test command above disables the runner's automatic hook installation.
Existing generated hooks already find `lefthook` on PATH inside `nix develop`;
they do not need reinstalling for this fix.

Zao's inspected common pre-push hook tried PATH, a now-missing hard-coded store
binary, then language package runners. The main checkout's development shell
provided only `gitleaks`, not `lefthook`. This branch had no development shell,
`.envrc` or tracked hook configuration. The main checkout's `lefthook.yml` had a
local-flake-input guard and optional pre-commit tools, with no aggregate Nix
check. This branch now tracks the same pre-push guard. It does not copy those
unrelated formatting/secret-scan hooks or change the main checkout.

Cost: run Git from this development shell. Outside it the old generated hook
can still say `Can't find lefthook in PATH`; an existing Git GUI must inherit
the shell's PATH too. No automatic direnv activation or shared-hook rewrite is
added. This does not enable the main checkout's separate pre-commit tools.
