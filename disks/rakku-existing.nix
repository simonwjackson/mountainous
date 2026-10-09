# Mount Rakku's existing disk. This file deliberately has no disko declaration.
# Repartitioning or adopting the shared disk layer would destroy the live instance.
{ ... }:
let
  # Keep the exact live fstab device names: changing aliases would restart
  # active mounts during switch. The deployment gate verifies their UUIDs.
  disk = "/dev/disk/by-partlabel/disk-main-root";
  options = [
    "compress=zstd"
    "noatime"
    "nodiratime"
    "discard=async"
    "space_cache=v2"
  ];
in
{
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=2G"
        "mode=755"
      ];
    };
    "/boot" = {
      device = "/dev/disk/by-partlabel/disk-main-ESP";
      fsType = "vfat";
      options = [
        "defaults"
        "umask=0077"
      ];
    };
    "/nix" = {
      device = disk;
      fsType = "btrfs";
      options = options ++ [ "subvol=@nix" ];
      neededForBoot = true;
    };
    "/var/log" = {
      device = disk;
      fsType = "btrfs";
      options = options ++ [ "subvol=@log" ];
    };
    "/tundra/permafrost" = {
      device = disk;
      fsType = "btrfs";
      options = options ++ [ "subvol=@permafrost" ];
      neededForBoot = true;
    };
  };
  swapDevices = [ { device = "/dev/disk/by-partlabel/disk-main-swap"; } ];

  environment.persistence."/tundra/permafrost" = {
    hideMounts = true;
    directories = [
      "/var/lib/systemd/coredump"
      "/var/lib/nixos"
      "/var/lib/tailscale"
      "/var/lib/hass"
      "/var/lib/zwave-js"
      # DynamicUser uses /var/cache/private/zwave-js. Persist its parent to
      # preserve systemd's private-directory ownership and symlink semantics.
      {
        directory = "/var/cache/private";
        mode = "0700";
      }
      "/var/lib/NetworkManager"
      {
        directory = "/var/lib/tsnet-proxy-habitat";
        user = "tsnet-proxy";
        group = "tsnet-proxy";
        mode = "0700";
      }
      {
        directory = "/home/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/home/simon";
        user = "simon";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/tundra/igloo";
        user = "simonwjackson";
        group = "users";
        mode = "0700";
      }
      {
        directory = "/nix/var/nix/profiles/per-user/simonwjackson";
        user = "simonwjackson";
        group = "users";
        mode = "0755";
      }
    ];
    files = [
      "/etc/machine-id"
      # SOPS requires the Ed25519 key before activation and account creation.
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_ed25519_key.pub"
    ];
  };
  # Existing RSA identity remains available throughout the transition.
  services.openssh.hostKeys = [
    {
      path = "/tundra/permafrost/etc/ssh/ssh_host_rsa_key";
      type = "rsa";
      bits = 4096;
    }
    {
      path = "/etc/ssh/ssh_host_ed25519_key";
      type = "ed25519";
    }
  ];
  system.stateVersion = "24.11";
}
