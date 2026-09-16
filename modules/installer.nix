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

          # Tailscale is present and running, but does not join by itself.
          #
          # Every installed host joins unattended, because each has its own SSH
          # host key planted before first boot and can therefore decrypt the
          # OAuth credential. This image cannot: it is built once and booted on
          # many machines, so there is no per-machine key to encrypt to.
          #
          # The alternative would be baking the credential into the image. That
          # puts it in the world-readable Nix store and on every USB written
          # from it -- a credential that can register nodes and delete devices
          # across the whole tailnet. A stick left in a hotel room must not be
          # able to do that.
          #
          # So the daemon is ready and joining is one command. `tailscale up`
          # with no key prints a login URL, which is usable from a console.
          services.tailscale.enable = true;

          users.users.root.openssh.authorizedKeys.keys = [ config.mountainous.sshKey ];

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

            mountainous installer.

              nmtui                       join a network
              ip -4 addr                  read this machine's address
              tailscale up --ephemeral    reach it from anywhere

            Then, from a workstation:

              ./scripts/install <host> /dev/disk/by-id/...

            --ephemeral matters. This image has no identity of its own, so a
            node it registers should disappear when it goes offline rather
            than pile up as another dead 'installer' in the tailnet.
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
