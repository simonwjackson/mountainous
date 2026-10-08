# RAM-only installation environment. Never embeds fleet credentials or host keys.
{
  config,
  inputs,
  lib,
  ...
}:
{
  flake.nixosConfigurations.unzen-installer = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      "${inputs.nixos-images-src}/nix/kexec-installer/module.nix"
      "${inputs.nixos-images-src}/nix/noninteractive.nix"
      (
        { pkgs, ... }:
        {
          nixpkgs.hostPlatform = "x86_64-linux";
          system.kexec-installer.name = "nixos-kexec-installer-noninteractive";
          # Override the image's ZFS-oriented kernel choice with the fleet's
          # tested kernel family and its matching out-of-tree bcachefs module.
          boot.kernelPackages = lib.mkForce pkgs.linuxPackages;
          boot.supportedFilesystems = [ "bcachefs" ];
          boot.kernelModules = [ "bcachefs" ];
          environment.systemPackages = [ pkgs.python3 ];
        }
      )
    ];
  };

  perSystem =
    {
      pkgs,
      system,
      self',
      ...
    }:
    lib.mkIf (system == "x86_64-linux") {
      packages.unzen-installer =
        config.flake.nixosConfigurations.unzen-installer.config.system.build.kexecInstallerTarball;
      packages.nixos-anywhere-verified = pkgs.nixos-anywhere.overrideAttrs (old: {
        src = inputs.nixos-anywhere-src;
        version = "git-${builtins.substring 0 7 inputs.nixos-anywhere-src.rev}";
        # OpenSSH takes the first value, so later --ssh-option flags cannot
        # override upstream's initial insecure defaults. Remove them here.
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/nixos-anywhere.sh \
            --replace-fail '"-o" "UserKnownHostsFile=/dev/null" "-o" "StrictHostKeyChecking=no"' \
                           '"-F" "/dev/null" "-o" "StrictHostKeyChecking=yes"'
        '';
      });
      checks.unzen-installer = import ../tests/unzen-installer.nix {
        inherit pkgs;
        inherit (inputs) nixos-images-src;
        verifiedTool = self'.packages.nixos-anywhere-verified;
        installer =
          config.flake.nixosConfigurations.unzen-installer.config.system.build.kexecInstallerTarball;
      };
    };
}
