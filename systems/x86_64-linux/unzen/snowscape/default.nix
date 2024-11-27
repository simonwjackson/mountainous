{pkgs, ...}: {
  imports = [
    ./disko.nix
  ];

  services.snapraid = {
    enable = true;

    parityFiles = [
      "/avalanche/disks/iceberg/00/0/snapraid.0.parity"
      "/avalanche/disks/iceberg/01/0/snapraid.1.parity"
    ];

    dataDisks = {
      iceberg02 = "/avalanche/disks/iceberg/02/0/";
      blizzard02 = "/avalanche/disks/blizzard/02/0/";
    };

    contentFiles = [
      "/var/lib/snapraid/snapraid.content"
      "/avalanche/disks/iceberg/00/0/snapraid.content"
      "/avalanche/disks/iceberg/01/0/snapraid.content"
      "/avalanche/disks/iceberg/02/0/snapraid.content"
      "/avalanche/disks/blizzard/02/0/snapraid.content" # Added content file for blizzard02
    ];

    exclude = [
      "*.tmp"
      "/tmp/"
      "/lost+found/"
      ".Trash-*/"
      "*.unrecoverable"
      "/gaming/games" # Added gaming directory exclusion
    ];

    extraConfig = ''
      # Block and hash size optimization
      blocksize 256
      hashsize 16

      # Autosave after every 500 GB
      autosave 500

      # Enable smart reporting
      smartctl d1 /dev/disk/by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C
      smartctl d2 /dev/disk/by-id/ata-WDC_WD80EFBX-68AZZN0_VRJVWS3K
      smartctl d3 /dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH3KRAG
      smartctl d4 /dev/disk/by-id/nvme-SAMSUNG_MZQLB7T6HMLA-00007_S4BGNC0R803650

      # Don't hide hidden files
      nohidden
    '';
  };

  environment.systemPackages = with pkgs; [
    xfsprogs # XFS tools
    smartmontools # For SMART monitoring
  ];

  # MergerFS mount for iceberg drives (HDDs)
  fileSystems."/avalanche/merged/iceberg" = {
    device = "/avalanche/disks/iceberg/02/0"; # Will expand as you add iceberg03-05
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=off"
      "dropcacheonclose=true"
      "category.create=mfs" # Most Free Space for new files
      "moveonenospc=true" # Try to move to another drive if ENOSPC
      "minfreespace=250G" # Minimum free space before considering full
      "fsname=mergerfs-iceberg"
      # Optimizations for HDDs
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=true" # Enable caching for better HDD performance
      "cache.symlinks=true" # Cache symlinks for better performance
    ];
    noCheck = true;
  };

  # MergerFS mount for blizzard drives (NVMes)
  fileSystems."/avalanche/merged/blizzard" = {
    device = "/avalanche/disks/blizzard/01/0:/avalanche/disks/blizzard/02/0";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial" # Partial file caching for SSDs
      "dropcacheonclose=true"
      "category.create=mfs" # Most Free Space for new files
      "moveonenospc=true"
      "minfreespace=100G" # Lower minimum for SSDs
      "fsname=mergerfs-blizzard"
      # Optimizations for NVMe
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=false" # Disable auto cache for SSDs
      "cache.symlinks=true" # Cache symlinks for better performance
      "cache.readdir=true" # Cache directory entries
      "direct_io=true" # Direct I/O for better SSD performance
    ];
    noCheck = true;
  };

  # Final merged pool (blizzard overlaying iceberg)
  fileSystems."/avalanche/groups/snowscape" = {
    device = "/avalanche/merged/blizzard/snowscape:/avalanche/merged/iceberg/snowscape";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=epff" # Existing Path, First Found - writes to first mount by default (blizzard)
      "category.search=ff" # First Found - faster searching
      "moveonenospc=true"
      "minfreespace=100G"
      "fsname=mergerfs-snowscape"
      # General optimizations
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=true"
      "cache.symlinks=true" # Cache symlinks for better performance
      "cache.readdir=true" # Cache directory entries
    ];
    noCheck = true;
  };

  fileSystems."/avalanche/groups/glacier" = {
    device = "/net/unzen/nfs/snowscape:/net/aka/nfs/snowscape";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=partial"
      "dropcacheonclose=true"
      "category.create=mfs" # Most Free Space for new files
      "category.search=ff" # First Found - faster searching
      "moveonenospc=true"
      "minfreespace=1G"
      "fsname=mergerfs-remote"
      # Network optimizations
      "posix_acl=true"
      "atomic_o_trunc=true"
      "big_writes=true"
      "auto_cache=true"
      "cache.symlinks=true" # Cache symlinks for better performance
      "cache.readdir=true" # Cache directory entries
    ];
    noCheck = true;
  };

  systemd.tmpfiles.rules = [
    "d /avalanche/groups/snowscape 0775 - - -"
    "L+ /snowscape 0775 media media - /avalanche/groups/snowscape"
    "L+ /glacier 0775 media media - /avalanche/groups/glacier"
  ];
}
