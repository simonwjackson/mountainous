# A bootable installer ISO with SSH already open.
#
# The point of this file is that the USB is touched exactly once. After it
# boots and joins a network, every later step happens over SSH from a
# workstation, including partitioning and hardware detection.
#
# Build:  nix build .#installer
# Write:  sudo dd if=result/iso/*.iso of=/dev/sdX bs=4M status=progress oflag=sync
{
  config,
  inputs,
  lib,
  ...
}:
{
  flake.nixosConfigurations.installer = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = { inherit inputs; };
    modules = [
      (
        { modulesPath, pkgs, ... }:
        {
          imports = [ "${modulesPath}/installer/cd-dvd/installation-cd-minimal.nix" ];

          nixpkgs.hostPlatform = "x86_64-linux";

          # The minimal CD enables wpa_supplicant. NetworkManager cannot share
          # the radio with it, and nmtui is the reason this ISO is usable on a
          # laptop with no ethernet port.
          networking.wireless.enable = lib.mkForce false;
          networking.networkmanager.enable = true;
          networking.hostName = "installer";

          services.openssh = {
            enable = true;
            settings = {
              PermitRootLogin = "yes";
              PasswordAuthentication = false;
            };
          };

          users.users.root.openssh.authorizedKeys.keys = [ config.cairn.sshKey ];

          # Tools the remote install needs to already be on the target.
          environment.systemPackages = with pkgs; [
            nixos-facter
            disko
            git
            jq
            parted
          ];

          nix.settings.experimental-features = [
            "nix-command"
            "flakes"
          ];

          services.getty.helpLine = lib.mkAfter ''

            cairn installer. Join a network with:  nmtui
            Then read the address with:            ip -4 addr
          '';
        }
      )
    ];
  };

  perSystem =
    { system, ... }:
    lib.mkIf (system == "x86_64-linux") {
      packages.installer = config.flake.nixosConfigurations.installer.config.system.build.isoImage;
    };
}
