# UNZEN and GitHub Actions Nix storage

## Finding

Martin Wimpress's **Nothing but Nix** is the likely match for the storage technique described by the operator. His first-person article explains that he needed enough temporary disk space to build full NixOS configurations and then upload successful outputs to FlakeHub Cache. The operator's account of the conversation is not independently verified.

Nothing but Nix provides build space on disposable GitHub-hosted Ubuntu runners. It is not a persistent cache or a native NixOS runner configuration. Do not run it on UNZEN.

## Sources inspected

The parent fetched Wimpress's article, the repository README, and the complete `action.yml`. GitHub reported `main` at commit `baf7355748bb5651f08b839669d6bb39051b2874` during this inspection.

- [Wimpress's first-person article](https://wimpysworld.com/posts/nothing-but-nix-github-actions/).
- [README at the observed commit](https://github.com/wimpysworld/nothing-but-nix/blob/baf7355748bb5651f08b839669d6bb39051b2874/README.md).
- [Action implementation at the observed commit](https://github.com/wimpysworld/nothing-but-nix/blob/baf7355748bb5651f08b839669d6bb39051b2874/action.yml).

No workflow using this action was executed for this research. Capacity and performance numbers below are the author's estimates, not measurements on the operator's repositories.

## How it works

The implementation checks for Ubuntu and rejects an existing `/nix` directory. It must run before installing Nix.

It allocates a loop-backed disk image using available space under `/mnt`, creates a Btrfs filesystem, and mounts it at `/nix`. Depending on the selected mode, it also deletes preinstalled software, allocates another image on the root filesystem, and adds that image to the Btrfs pool. It uses compression and RAID0 allocation. This is a temporary CI filesystem, not a storage-redundancy design.

| Mode | Author's approximate `/nix` capacity | Trade-off |
| --- | --- | --- |
| `holster` | 65 GB | Uses `/mnt` space without purging tools. |
| `carve` | 85 GB | Combines free space from `/` and `/mnt` without purging tools. |
| `cleave` | 115 GB | Removes Docker, Snap, tool caches, and other preinstalled software. |
| `rampage` | 130 GB | Deletes more software and can break workflows that depend on it. |

Actual capacity depends on the runner image and filesystem layout. Background reclamation can lag behind a large build. The documented `witness-carnage: true` setting waits for reclamation and therefore adds setup time.

The action creates `/nix/build`. The README recommends setting Nix's `build-dir = /nix/build` so temporary build files also use the reclaimed space. Expanding the store alone does not move build scratch files.

Its source contains no binary-cache upload or cross-job store-restoration mechanism. Wimpress uses a separate service, FlakeHub Cache, for persistent reuse.

## Relevance to UNZEN

UNZEN already has Nix installed and uses a shared bcachefs pool. The action's destructive Ubuntu-specific cleanup and loop-image construction do not belong on this host.

The useful idea to adopt is separating three needs: build scratch space, retained Nix store outputs, and sharing outputs with other machines.

A read-only evaluation of the `cairn` configuration found:

- `boot.tmp.useTmpfs = true` and `boot.tmp.tmpfsSize = "50%"`.
- No explicit `build-dir` entry in `nix.settings`.
- Only `https://cache.nixos.org/` in `nix.settings.substituters`.

These are evaluated repository settings, not a fresh observation of the running daemon's environment. A separate authenticated `findmnt /tmp` confirmed that UNZEN's running system mounts `/tmp` as tmpfs. Earlier authenticated inspection found approximately 62 GiB RAM and 1.7 TiB available disk space on UNZEN.

For large builds, verify the daemon's effective scratch directory and consider an explicit disk-backed `build-dir`. Otherwise, temporary files can exhaust memory-backed space despite ample disk capacity. This changes host behavior and requires a separate implementation decision; this research does not apply it.

## Cross-repository caching

The operator expects more than 30 repositories. A separate researcher fetched the four primary sources below. Its initial search hit HTTP 429 rate limiting; the retry fetched the official URLs directly and completed. These are documentation findings, not measured cache hits or CI execution on UNZEN.

| Mechanism | Reuse | Cost or limit |
| --- | --- | --- |
| Persistent UNZEN `/nix/store` | Jobs using the same store can reuse matching store objects, including objects used by multiple repositories. | Garbage collection can delete unrooted outputs. Different inputs and platforms can produce different store objects. Actual reuse remains unmeasured. |
| GitHub Actions cache | Restores archived paths using cache keys and repository/branch access rules. | It is not a cross-repository Nix binary cache. Archives have retention and eviction rules. |
| Shared Nix binary cache | Supplies matching store objects to other machines or GitHub-hosted jobs. | Requires publishing, storage, network transfers, and a deliberate trust policy. |

GitHub documents cache reuse within a repository, with restrictions on branch and PR cache access. Nix documents garbage collection as deleting objects unreachable from roots. Persistent storage is therefore not a promise of indefinite retention.

Nix's substituters provide the mechanism for downloading store objects rather than rebuilding them. Cachix documents sharing those objects between developers and CI, with separate read and write credentials. A cache does not make different builds equivalent. Reusing a Nix-provided Node runtime also does not automatically cache arbitrary npm build or test results.

### Recommendation

Start with a centrally managed set of native runners, persistent local store reuse, disk-backed build scratch space, and explicit retention. Thirty repositories do not mean thirty concurrent jobs. Set aggregate build limits and verify reuse with representative repositories before increasing concurrency.

Add a shared binary cache when repeated outputs need to reach GitHub-hosted jobs, another home runner, or development machines. Repository count alone does not justify a new cache service. Cachix and the FlakeHub Cache mentioned in Wimpress's article are candidates, not a selected provider. This research did not compare self-hosted cache products or pricing.

Use Nothing but Nix only for GitHub-hosted Ubuntu jobs that actually need extra temporary space. Choose the least destructive mode that provides enough room and pin the action to a reviewed commit. The cost is setup time and, in the purge modes, removal of tools that other workflow steps can need.

### Trust and retention

Keep cache publication credentials and signing keys out of untrusted PR jobs. Signed cache acceptance does not establish that cached software is harmless and does not isolate workflow execution. Do not add an untrusted runner to Nix's `trusted-users`; the Nix manual describes that privilege as effectively root access.

Choose a GC-root lifecycle separately from workspace cleanup. UNZEN's existing server layer schedules weekly collection with `--delete-older-than 14d`, but this does not guarantee retention of arbitrary unrooted CI outputs. Retaining every build indefinitely would consume the same pool used by the OS and data.

Keep signature checks enabled, use administrator-approved cache keys and substituters, and limit who can publish. A shared local store also requires a deliberate policy for builds containing private data. Runner isolation and cache reuse are separate decisions.

### Additional sources

- [GitHub dependency caching reference](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).
- [Nix 2.34 garbage collection reference](https://nix.dev/manual/nix/2.34/command-ref/nix-store/gc).
- [Nix 2.34 configuration reference](https://nix.dev/manual/nix/2.34/command-ref/conf-file).
- [Cachix action README](https://raw.githubusercontent.com/cachix/cachix-action/master/README.md).

No runner, binary-cache service, storage layout, or deployment was changed. The only repository change from this research is this note. Workload speed, cache overlap, retention needs, and the daemon's effective build scratch directory still need runtime validation before implementation.
