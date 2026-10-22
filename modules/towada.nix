# The Towada enclosure as a bcachefs pool on its own filesystem, separate from
# the host's root pool. A missing or partial enclosure never blocks boot: the
# pool mounts only on demand, and only after admission proves that every
# listed member is present and belongs to one bcachefs filesystem.
#
# During the conversion from XFS, members still holding XFS data can be
# listed in `legacy`. They mount read-only, on demand, at their old paths.
{ ... }:
let
  towada =
    {
      config,
      lib,
      pkgs,
      utils,
      ...
    }:
    let
      cfg = config.mountainous.features.towada;
      byId = serial: "/dev/disk/by-id/${cfg.idPrefix}${serial}${cfg.idSuffix}";
      # Attribute order is by disk id, so the device list is stable.
      # The NVMe counts as a member only once add-fast has joined it.
      fastJoined = cfg.fast != null && cfg.fast.joined;
      memberPaths = map byId (builtins.attrValues cfg.members) ++ lib.optional fastJoined cfg.fast.path;
      memberLabels =
        map (id: "${cfg.label}.${id}") (builtins.attrNames cfg.members)
        ++ lib.optional fastJoined cfg.fast.label;
      fastGroup = if cfg.fast == null then null else builtins.head (lib.splitString "." cfg.fast.label);
      mountUnit = "${utils.escapeSystemdPath cfg.mountPoint}.mount";
      legacyPath = id: "/srv/shores/towada/${id}";
      convertConfig = pkgs.writeText "towada-convert.json" (
        builtins.toJSON {
          inherit (cfg)
            mountPoint
            uuid
            idPrefix
            idSuffix
            members
            legacy
            dataReplicas
            metadataReplicas
            twoCopies
            label
            ;
          inherit mountUnit fastGroup;
          inherit (cfg) fast;
          legacyUnits = lib.mapAttrs (id: _: "${utils.escapeSystemdPath (legacyPath id)}.mount") cfg.legacy;
          inherit (cfg.copy) fromGid toGid;
          copyExclude = cfg.copy.exclude;
        }
      );
      convert = pkgs.writeShellApplication {
        name = "towada-convert";
        runtimeInputs = [
          pkgs.bcachefs-tools
          pkgs.rsync
          pkgs.attr
          pkgs.util-linux
          pkgs.coreutils
          pkgs.systemd
        ];
        text = ''
          export TOWADA_CONFIG=${convertConfig}
          exec ${pkgs.python3}/bin/python3 ${./towada-convert.py} "$@"
        '';
      };
      admission = pkgs.writeShellApplication {
        name = "towada-admission";
        runtimeInputs = [
          pkgs.util-linux
          pkgs.coreutils
          pkgs.systemd
        ];
        text = ''
          # USB disks can appear seconds after boot reaches this unit. Wait for
          # every member, up to the limit, before calling one missing.
          deadline=$(( $(date +%s) + ${toString cfg.admissionTimeout} ))
          while :; do
            missing=""
            for dev in ${lib.escapeShellArgs memberPaths}; do
              test -b "$dev" || missing="$missing $dev"
            done
            [ -z "$missing" ] && break
            if [ "$(date +%s)" -ge "$deadline" ]; then
              echo "towada members missing after ${toString cfg.admissionTimeout}s:$missing" >&2
              exit 1
            fi
            udevadm settle --timeout=2 2>/dev/null || true
            sleep 1
          done
          # Every listed member must be present and carry the pool's UUID.
          for dev in ${lib.escapeShellArgs memberPaths}; do
            type=$(blkid -p -o value -s TYPE "$dev" || true)
            test "$type" = bcachefs || { echo "towada member is not bcachefs ($type): $dev" >&2; exit 1; }
            this=$(blkid -p -o value -s UUID "$dev")
            test "$this" = ${lib.escapeShellArg cfg.uuid} || { echo "towada member has another UUID ($this): $dev" >&2; exit 1; }
          done
          echo "towada admitted: ${toString (builtins.length memberPaths)} members, one filesystem"
        '';
      };
    in
    {
      options.mountainous.features.towada = {
        enable = lib.mkEnableOption "the Towada bcachefs pool";
        mountPoint = lib.mkOption {
          type = lib.types.str;
          default = "/srv/lakes/towada";
        };
        idPrefix = lib.mkOption {
          type = lib.types.str;
          default = "usb-TerraMas_TDAS_";
          description = "Prefix of the members' /dev/disk/by-id names.";
        };
        idSuffix = lib.mkOption {
          type = lib.types.str;
          default = "-0:0";
        };
        uuid = lib.mkOption {
          type = lib.types.str;
          description = "Filesystem UUID, chosen ahead and given to bcachefs format.";
        };
        members = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "02" = "VGH3KRAG";
          };
          description = "Every bcachefs member: disk id -> serial. All must be present to mount.";
        };
        legacy = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = { };
          example = {
            "00" = "7SGKDA3C";
          };
          description = "XFS disks not yet converted: id -> serial. Mounted read-only on demand at /srv/shores/towada/<id>.";
        };
        usb = lib.mkOption {
          type = lib.types.listOf (lib.types.attrsOf lib.types.str);
          # The TerraMaster TDAS bridge, as seen on Zao on 2026-10-22.
          default = [
            {
              vendor = "174c";
              product = "235c";
            }
          ];
          description = "USB bridges of the enclosure; autosuspend is disabled for them.";
        };
        admissionTimeout = lib.mkOption {
          type = lib.types.ints.positive;
          default = 90;
          description = "Seconds admission waits for USB members to appear before refusing.";
        };
        fast = lib.mkOption {
          default = null;
          description = "An NVMe member that takes new writes and caches hot reads; data moves to the disks in the background.";
          type = lib.types.nullOr (
            lib.types.submodule {
              options = {
                path = lib.mkOption {
                  type = lib.types.str;
                  description = "Stable /dev/disk/by-id path of the whole device.";
                };
                label = lib.mkOption {
                  type = lib.types.str;
                  default = "nvme.0";
                  description = "bcachefs label; the part before the dot is the target group.";
                };
                joined = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Set once towada-convert add-fast has run; admission and probes then require it.";
                };
              };
            }
          );
        };
        dataReplicas = lib.mkOption {
          type = lib.types.ints.positive;
          default = 1;
          description = "Default copies of file data, set at format. Replaceable data keeps one.";
        };
        metadataReplicas = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
          description = "Copies of the filesystem's own metadata, so one lost disk never loses the pool.";
        };
        twoCopies = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [ "photos" ];
          description = "Pool-relative paths kept in two copies (data_replicas=2); new files inside inherit it.";
        };
        label = lib.mkOption {
          type = lib.types.str;
          default = "towada";
        };
        mounts = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          internal = true;
          readOnly = true;
          description = "The pool and legacy mounts; test VMs add these to their own set.";
          default = {
            ${cfg.mountPoint} = {
              # mount.bcachefs scans for every member with this UUID. A colon
              # list of members would make systemd wait for a device that
              # never appears.
              device = "/dev/disk/by-uuid/${cfg.uuid}";
              fsType = "bcachefs";
              options = [
                "noauto"
                "nofail"
                "noatime"
                "x-systemd.requires=towada-admission.service"
                "x-systemd.after=towada-admission.service"
                "x-systemd.mount-timeout=10min"
              ];
            };
          }
          // lib.mapAttrs' (
            id: serial:
            lib.nameValuePair (legacyPath id) {
              device = "${byId serial}-part1";
              fsType = "xfs";
              options = [
                "ro"
                "noauto"
                "nofail"
                "x-systemd.device-timeout=30s"
              ];
            }
          ) cfg.legacy;
        };
        copy = {
          fromGid = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 993;
            description = "Media group on the old host's disks.";
          };
          toGid = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = config.users.groups.media.gid or 390;
            defaultText = "the media group";
          };
          exclude = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [
              "snapraid.content"
              "snapraid.*.parity"
              "lost+found"
            ];
            description = "Root-level paths on old disks that are not data.";
          };
        };
      };
      config = lib.mkIf cfg.enable {
        assertions = [
          {
            assertion = cfg.members != { };
            message = "towada needs at least one member";
          }
          {
            assertion = lib.all (s: !(builtins.elem s (builtins.attrValues cfg.members))) (
              builtins.attrValues cfg.legacy
            );
            message = "a towada disk cannot be both a bcachefs member and a legacy XFS disk";
          }
        ];
        boot.supportedFilesystems = [ "bcachefs" ];
        environment.systemPackages = [
          pkgs.bcachefs-tools
          convert
        ];

        systemd.services.towada-admission = {
          description = "Admit the Towada pool only when every member is present";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${admission}/bin/towada-admission";
            TimeoutStartSec = cfg.admissionTimeout + 30;
          };
          # The pool mount requires this unit, so restarting it on a config
          # change would unmount the pool under running consumers. New
          # admission rules take effect at the next mount instead.
          restartIfChanged = false;
        };

        fileSystems = cfg.mounts;

        # USB autosuspend would drop the enclosure's link while it idles.
        services.udev.extraRules = lib.concatMapStrings (usb: ''
          ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="${usb.vendor}", ATTR{idProduct}=="${usb.product}", TEST=="power/control", ATTR{power/control}="on"
        '') cfg.usb;
        systemd.tmpfiles.rules = [ "d ${cfg.mountPoint} 0755 root root -" ];
        # The storage probe compares the mounted pool with these labels.
        environment.etc."towada/members".text = lib.concatLines memberLabels;

        # Hosts may list scrub targets explicitly (Unzen lists only /), so add
        # the pool to that list rather than relying on discovery.
        services.bcachefs.autoScrub = {
          enable = true;
          fileSystems = [ cfg.mountPoint ];
        };
        # A scrub must never pull the pool in; it runs only while mounted.
        systemd.services."bcachefs-scrub-${utils.escapeSystemdPath cfg.mountPoint}".unitConfig = {
          ConditionPathIsMountPoint = cfg.mountPoint;
        };
      };
    };
in
{
  nixos.modules.towada = towada;
  perSystem =
    { pkgs, lib, ... }:
    {
      checks = {
        towada-verify =
          pkgs.runCommand "towada-verify"
            {
              nativeBuildInputs = [
                pkgs.python3
                pkgs.findutils
                pkgs.coreutils
              ];
            }
            ''
              python3 ${../tests/test_towada_verify.py} ${./towada-convert.py}
              touch $out
            '';
      }
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isx86_64 {
        towada-vm = import ../tests/towada-vm.nix {
          inherit pkgs;
          towadaModule = towada;
        };
      };
    };
}
