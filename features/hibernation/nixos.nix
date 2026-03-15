{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkAfter mkDefault mkIf mkMerge;
  cfg = config.mountainous.features.hibernation;
  usesBtrfsSwapfile = cfg.swap.mode == "swapfile-btrfs";
  bootMountPoint =
    if config.boot.loader.systemd-boot.xbootldrMountPoint != null
    then config.boot.loader.systemd-boot.xbootldrMountPoint
    else config.boot.loader.efi.efiSysMountPoint;

  patchResumeOffset = pkgs.writeText "mountainous-patch-hibernate-resume-offset.py" ''
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

    if updated:
        entry.write_text("\n".join(lines) + ("\n" if had_trailing_newline else ""))
  '';

  updateResumeOffset = pkgs.writeShellScript "mountainous-update-hibernate-resume-offset" ''
    #!${pkgs.runtimeShell}
    set -euo pipefail

    swapfile=${lib.escapeShellArg cfg.swap.path}
    entriesDir=${lib.escapeShellArg "${bootMountPoint}/loader/entries"}

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
      ${pkgs.python3}/bin/python3 ${patchResumeOffset} "$entry" "$resumeOffset"
    done
  '';
in {
  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.resumeDevice != "";
          message = "mountainous.features.hibernation.resumeDevice must be set when hibernation is enabled";
        }
        {
          assertion = !usesBtrfsSwapfile || cfg.swap.path != null;
          message = "mountainous.features.hibernation.swap.path must be set when using swapfile-btrfs mode";
        }
        {
          assertion = !usesBtrfsSwapfile || config.boot.loader.systemd-boot.enable;
          message = "mountainous.features.hibernation.swapfile-btrfs currently requires boot.loader.systemd-boot.enable = true";
        }
      ];

      boot.resumeDevice = mkDefault cfg.resumeDevice;
    }

    (mkIf usesBtrfsSwapfile {
      boot.loader.systemd-boot.extraInstallCommands = mkAfter ''
        ${updateResumeOffset}
      '';

      systemd.services.update-hibernate-resume-offset = {
        description = "Update systemd-boot entries with hibernation resume_offset";
        after = [
          "local-fs.target"
          "swap.target"
        ];
        wants = ["swap.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig.Type = "oneshot";
        script = ''
          ${updateResumeOffset}
        '';
      };
    })
  ]);
}
