# The RAM installer that `nix run .#install` kexecs into, for every system.
#
# It is the upstream nixos-images kexec installer plus Tailscale. When the
# machine being replaced has Tailscale state, the kexec step carries that
# state into the installer, which then comes back on the tailnet as the same
# node, at the same address, with the same SSH host key. A remote host whose
# SSH is reachable only over Tailscale therefore stays reachable for the whole
# install.
#
# The image itself holds no credentials. The state is read from the machine at
# kexec time and lives only in that machine's RAM.
{
  config,
  inputs,
  lib,
  ...
}:
let
  src = inputs.nixos-images-src;
  systems = [
    "x86_64-linux"
    "aarch64-linux"
  ];

  installer =
    system:
    inputs.nixpkgs.lib.nixosSystem {
      modules = [
        "${src}/nix/kexec-installer/module.nix"
        "${src}/nix/noninteractive.nix"
        (
          { config, pkgs, ... }:
          {
            nixpkgs.hostPlatform = system;
            system.kexec-installer.name = "nixos-kexec-installer-noninteractive";
            services.tailscale.enable = true;

            # Every filesystem a fleet host formats. disko wipes the partition
            # table before it runs mkfs, so a missing tool here destroys a disk
            # and installs nothing. Same kernel choice as unzen-installer.nix.
            boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
            boot.supportedFilesystems = [
              "btrfs"
              "bcachefs"
            ];
            boot.kernelModules = [ "bcachefs" ];

            # The upstream run script, plus two steps:
            #   1. before it packs the extra initrd, copy the running machine's
            #      Tailscale state;
            #   2. under systemd, jump with `systemctl kexec` instead of a raw
            #      `kexec -e`. Upstream kexecs 6 s after the script returns,
            #      with every service still running and every disk mounted. On
            #      Oracle A1 VMs that hung in 3 of 5 runs (Yari 2026-10-12,
            #      Fuji 2026-10-14 twice): disk write errors, then kexec blocked
            #      until an OCI reset. A sync and read-only remount just before
            #      did not help. systemctl kexec stops services and unmounts
            #      first, as a normal reboot does. It keeps the loaded
            #      installer: NixOS's prepare-kexec skips itself when a kernel
            #      is already loaded. Without systemd, the raw path stays.
            system.build.kexecRun = lib.mkForce (
              pkgs.runCommand "kexec-run" { } ''
                install -D -m 0755 ${src}/nix/kexec-installer/kexec-run.sh $out
                substituteInPlace $out --replace-fail 'find . | cpio' '${
                  lib.concatStringsSep "\n" [
                    "if [ -f /var/lib/tailscale/tailscaled.state ]; then"
                    "  mkdir -p tailscale"
                    "  cp -a /var/lib/tailscale/tailscaled.state tailscale/"
                    "fi"
                    "find . | cpio"
                  ]
                }'
                substituteInPlace $out --replace-fail ${lib.escapeShellArg "nohup sh -c \"sleep 6 && cd / && '$SCRIPT_DIR/kexec' -e \${kexec_extra_flags}\" &"} ${
                  lib.escapeShellArg (
                    lib.concatStringsSep "\n" [
                      "if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1; then"
                      "  nohup sh -c \"sleep 6 && systemctl kexec\" &"
                      "else"
                      "  nohup sh -c \"sleep 6 && cd / && '$SCRIPT_DIR/kexec' -e \${kexec_extra_flags}\" &"
                      "fi"
                    ]
                  )
                }
                sed -i \
                  -e 's|@init@|${config.system.build.toplevel}/init|' \
                  -e 's|@kernelParams@|${lib.escapeShellArgs config.boot.kernelParams}|' \
                  $out
                ${pkgs.shellcheck}/bin/shellcheck $out
              ''
            );

            # Restore it next to the SSH keys that upstream already restores.
            boot.initrd.systemd.services.restore-state-from-initrd.script = lib.mkAfter ''
              if [[ -f tailscale/tailscaled.state ]]; then
                install -d -m 700 /sysroot/var/lib/tailscale
                install -m 600 tailscale/tailscaled.state /sysroot/var/lib/tailscale/
              fi
            '';
          }
        )
      ];
    };
in
{
  flake.nixosConfigurations = lib.listToAttrs (
    map (system: lib.nameValuePair "kexec-installer-${system}" (installer system)) systems
  );

  perSystem =
    { pkgs, system, ... }:
    let
      tarball =
        config.flake.nixosConfigurations."kexec-installer-${system}".config.system.build.kexecInstallerTarball;
    in
    lib.mkIf (lib.elem system systems) {
      packages.kexec-installer = tarball;
      # The VM test needs KVM, which only the x86_64 machines have.
      checks = lib.optionalAttrs (system == "x86_64-linux") {
        kexec-installer = import ../tests/kexec-installer.nix {
          inherit pkgs;
          nixos-images-src = src;
          installer = tarball;
        };
      };
    };
}
