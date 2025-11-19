# Installing NixOS on Oracle Cloud 1GB Micro Instances

## Problem

nixos-anywhere fails on Oracle Cloud VM.Standard.E2.1.Micro (1GB RAM) instances due to:
- kexec OOM (Out of Memory) during boot
- Continuous garbage collection cycles during package installation
- Deployment hanging for 2+ hours

## Solutions

### Recommended: Netboot Method

Boot the NixOS installer via netboot.xyz, which allows nixos-anywhere to skip the kexec phase entirely.

**Main Tutorial:**
- https://mtlynch.io/notes/nix-oracle-cloud/
  - Most recent (Feb 2025) and complete guide
  - Specifically addresses 1GB RAM limitation
  - Uses netboot.xyz method

**Short Guide:**
- https://prithu.dev/notes/installing-nixos-on-oracle-cloud-arm-instance/
  - Terse but simple netboot steps

**netboot.xyz Documentation:**
- https://netboot.xyz/docs/kb/providers/oci/
  - Official guide for Oracle Cloud

### Alternative: Pre-build System Image

Build the NixOS closure locally (with plenty of RAM), then upload to Oracle.

**Guide:**
- https://lantian.pub/en/article/modify-computer/nixos-low-ram-vps.lantian/
  - Creating disk images for low RAM VPS
  - Pre-build approach

## Official nixos-anywhere Documentation

**Limited RAM Guide:**
- https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/limited-ram.md
  - Official guide for RAM-constrained systems

**Installing without kexec:**
- https://nix-community.github.io/nixos-anywhere/howtos/no-os.html
  - Skip kexec when booting from NixOS installer
  - nixos-anywhere detects `VARIANT_ID=installer` and skips kexec automatically

## Community Resources

**NixOS Discourse - Oracle Cloud ARM:**
- https://discourse.nixos.org/t/nixos-on-free-oracle-cloud-arm-a1/17474
  - Community experiences and tips

**GitHub Gist - Oracle Cloud Installation:**
- https://gist.github.com/itsnebulalol/a5b80b996f434649942ece9fe31c9258
  - Step-by-step installation notes

## What We Tried

1. ✅ **Added 2GB swap** - Helped kexec succeed initially
2. ❌ **Direct nixos-anywhere deployment** - Stuck in GC cycles for 2+ hours
3. ⏭️ **Next: Netboot method** - Skip kexec entirely

## Notes

- Oracle Cloud free tier: 2x VM.Standard.E2.1.Micro (1 CPU / 1GB RAM)
- Systems: yake (129.146.197.189), nasu (129.146.168.23)
- Both use XFS root filesystem with 2GB swap
- SSH host keys generated and encrypted in secrets/keys/hosts/
