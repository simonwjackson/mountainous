{
  config,
  lib,
  pkgs,
  hyprdynamicmonitors,
  ...
}: let
  updateHibernateResumeOffset = pkgs.writeShellScript "yuki-update-hibernate-resume-offset" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    swapfile=/swap/swapfile
    entriesDir=/boot/efi/loader/entries

    if [[ ! -e "$swapfile" ]]; then
      echo "skipping hibernation resume_offset update: $swapfile does not exist"
      exit 0
    fi

    if [[ ! -d "$entriesDir" ]]; then
      echo "skipping hibernation resume_offset update: $entriesDir does not exist"
      exit 0
    fi

    resumeOffset="$(${pkgs.btrfs-progs}/bin/btrfs inspect-internal map-swapfile -r "$swapfile")"

    if [[ -z "$resumeOffset" ]]; then
      echo "failed to determine resume_offset for $swapfile" >&2
      exit 1
    fi

    for entry in "$entriesDir"/*.conf; do
      [[ -e "$entry" ]] || continue

      ${pkgs.python3}/bin/python3 - "$entry" "$resumeOffset" <<'PY'
from pathlib import Path
import re
import sys

entry = Path(sys.argv[1])
resume_offset = sys.argv[2]
text = entry.read_text()
had_trailing_newline = text.endswith("\n")
lines = text.splitlines()
updated = False

for index, line in enumerate(lines):
    if line.startswith("options "):
        options = re.sub(r"(^| )resume_offset=[^ ]+", "", line[8:]).split()
        options.append(f"resume_offset={resume_offset}")
        lines[index] = "options " + " ".join(options)
        updated = True
        break

if not updated:
    raise SystemExit(f"missing options line in {entry}")

entry.write_text("\n".join(lines) + ("\n" if had_trailing_newline else ""))
PY
    done
  '';
in {
  imports = [
    ./hardware.nix
    ./disko.nix
    ./quirks.nix
    ../../modules/nixos/device
    ../../features/gaming/nixos.nix
  ];

  home-manager.users.simonwjackson = {
    imports = [
      ../../features/gaming/home.nix
      hyprdynamicmonitors.homeManagerModules.default
    ];

    home.packages = [pkgs.lazygit];
  };

  networking.hostName = "yuki";

  mountainous = {
    presets = {
      core.enable = true;
      workstation.enable = true;
      desktop.enable = true;
      portable.enable = true;
    };

    features = {
      firefox = {
        enable = true;
        cascade.enable = true;
      };
      bluetooth.enable = true;
      keyboard.enable = true;
    };
  };

  time.timeZone = "America/Denver";

  mountainous.device = {
    role = "portable";
    capabilities = {
      battery = true;
      formFactor = "laptop";
      touchscreen = false;
    };
  };

  services = {
    geoclue2 = {
      enable = true;
      enableDemoAgent = true;
      geoProviderUrl = "https://api.beacondb.net/v1/geolocate";
      submissionUrl = "https://api.beacondb.net/v2/geosubmit";
      appConfig = {
        automatic-timezoned = {
          isAllowed = true;
          isSystem = true;
          users = [];
        };
        gammastep = {
          isAllowed = true;
          isSystem = false;
          users = [];
        };
      };
    };

    avahi = {
      enable = true;
      nssmdns4 = true;
      nssmdns6 = true;
    };

    timesyncd.enable = lib.mkDefault true;
  };

  mountainous.gaming.enable = true;

  users.users.simonwjackson.extraGroups = [
    "networkmanager"
    "video"
  ];

  boot = {
    # Arrow Lake-H suspend-to-idle support requires Linux 6.15 or newer.
    kernelPackages = pkgs.linuxPackages_latest;

    # Hibernating to a swapfile on btrfs also needs the filesystem device and
    # the swapfile's physical resume_offset.
    resumeDevice = "/dev/mapper/cryptroot";

    loader.systemd-boot.extraInstallCommands = ''
      ${updateHibernateResumeOffset}
    '';
  };

  systemd.services.update-hibernate-resume-offset = {
    description = "Update yuki systemd-boot entries with hibernation resume_offset";
    after = [
      "local-fs.target"
      "swap.target"
    ];
    wants = ["swap.target"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      ${updateHibernateResumeOffset}
    '';
  };

  swapDevices = [
    {
      device = "/swap/swapfile";
      size = 20480;
    }
  ];

  # gaming module enables graphics, pipewire, and rtkit
  # just add the 32-bit extras for native 32-bit apps
  hardware.graphics.enable32Bit = true;

  services.xserver.videoDrivers = ["modesetting"];

  system.stateVersion = "24.11";
}
