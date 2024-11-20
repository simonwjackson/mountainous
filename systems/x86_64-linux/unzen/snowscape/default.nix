{pkgs, ...}: {
  import = [
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
    };

    contentFiles = [
      "/var/lib/snapraid/snapraid.content"
      "/avalanche/disks/iceberg/00/0/snapraid.content"
      "/avalanche/disks/iceberg/01/0/snapraid.content"
      "/avalanche/disks/iceberg/02/0/snapraid.content"
    ];

    # Set up common exclusions
    exclude = [
      "*.tmp"
      "/tmp/"
      "/lost+found/"
      ".Trash-*/"
      "*.unrecoverable"
    ];

    sync.interval = "03:00";

    scrub = {
      interval = "Mon *-*-* 04:00:00"; # Weekly on Monday at 4 AM
      plan = 8; # Check 8% of the array
      olderThan = 10; # Only scrub data not checked in the last 10 days
    };

    extraConfig = ''
      # Block and hash size optimization
      blocksize 256
      hashsize 16

      # Autosave after every 500 GB
      autosave 500

      # Enable smart reporting
      smartctl d1 /dev/disk-by-id/ata-WDC_WD80EFAX-68LHPN0_7SGKDA3C
      smartctl d2 /dev/disk/by-id/ata-WDC_WD80EFBX-68AZZN0_VRJVWS3K
      smartctl d3 /dev/disk/by-id/ata-WDC_WD80EDAZ-11TA3A0_VGH3KRAG

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
      "sync_read=false" # Async reads for better performance
      "writeback_cache=true" # Enable writeback caching
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
      "sync_read=false"
      "writeback_cache=false" # Disable writeback cache for SSDs
      "direct_io=true" # Direct I/O for better SSD performance
    ];
    noCheck = true;
  };

  # Final merged pool (blizzard overlaying iceberg)
  fileSystems."/avalanche/groups/snowscape" = {
    device = "/avalanche/merged/blizzard:/avalanche/merged/iceberg";
    fsType = "fuse.mergerfs";
    options = [
      "defaults"
      "allow_other"
      "use_ino"
      "cache.files=auto" # Automatic caching based on underlying fs
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
      "sync_read=false"
      "writeback_cache=auto" # Automatic based on underlying fs
    ];
    noCheck = true;
  };
}
