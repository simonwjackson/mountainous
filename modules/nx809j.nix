{ inputs, ... }:
{
  nixos.modules.nx809j =
    {
      utils,
      lib,
      pkgs,
      options,
      ...
    }:
    {
      assertions = [
        {
          assertion = !(options ? disko);
          message = "The NX809J must never import disk, permafrost or disko.";
        }
      ];
      boot.kernelPackages = pkgs.linuxPackagesFor (
        import ../lib/nx809j-kernel.nix { inherit pkgs inputs; }
      );
      services.korriProduct.kernel.overrideReason = "NX809J drivers are in the board port, based on linux-next.";
      services.udev.packages = [
        (pkgs.runCommand "nx809j-modem-recovery-rule" { } ''
          install -Dm444 ${inputs.nx809j-port}/device/rootfs/usr/lib/udev/rules.d/80-nx809j-modem-recovery.rules \
            $out/lib/udev/rules.d/80-nx809j-modem-recovery.rules
        '')
      ];
      hardware.deviceTree = {
        enable = true;
        name = "qcom/kaanapali-nubia-nx809j.dtb";
      };
      boot.loader.systemd-boot.installDeviceTree = true;
      boot.loader.efi.canTouchEfiVariables = false;
      boot.kernelParams = [
        "mem_sleep_default=s2idle"
        "systemd.gpt_auto=0"
        "rd.systemd.gpt_auto=0"
      ];
      boot.initrd.systemd.enable = true;
      # UFS, SCSI disk and ext4 are built into the board kernel.
      boot.initrd.availableKernelModules = lib.mkForce [ ];
      boot.initrd.kernelModules = [
        "msm"
        "rmtfs_mem"
      ];
      # The first three files come from linux-firmware. The signed ZAP image
      # must match this phone; listing a name does not supply a private blob.
      boot.initrd.extraFirmwarePaths = [
        "qcom/gen80200_sqe.fw"
        "qcom/gen80200_gmu.bin"
        "qcom/gen80200_aqe.fw"
        "qcom/kaanapali/nubia/nx809j/gen80200_zap.mbn"
      ];
      boot.kernelModules = [
        "qcom_q6v5_pas"
        "ipa"
      ];

      # Keep private modem state out of the store and initrd. Only read UFS
      # while preparing ordinary files on the mounted Linux root. Carry these
      # files across switch-root, not an initrd daemon with an ephemeral copy.
      boot.initrd.systemd.services.nx809j-rmtfs-copies = let
        devices = map (label: "${utils.escapeSystemdPath "/dev/disk/by-partlabel/${label}"}.device")
          [ "modemst1" "modemst2" "fsc" "fsg" ];
      in {
        wantedBy = [ "initrd.target" ];
        after = [ "sysroot.mount" ] ++ devices;
        requires = [ "sysroot.mount" ] ++ devices;
        before = [ "initrd-switch-root.target" ];
        unitConfig.DefaultDependencies = false;
        serviceConfig.Type = "oneshot";
        path = [ pkgs.coreutils ];
        script = ''
          set -eu
          dir=/sysroot/var/lib/rmtfs
          [ "$(realpath -m "$dir")" = "$dir" ]
          install -d -m 0700 "$dir"
          for pair in modemst1:modem_fs1 modemst2:modem_fs2 fsc:modem_fsc fsg:modem_fsg; do
            file="$dir/''${pair#*:}"
            [ ! -L "$file" ]
            if [ -e "$file" ]; then
              [ -f "$file" ] && [ -s "$file" ] || exit 1
              continue
            fi
            part="/dev/disk/by-partlabel/''${pair%%:*}"
            [ -b "$part" ]
            tmp=$(mktemp "$dir/.copy.XXXXXXXX")
            trap 'rm -f "$tmp"' EXIT
            cat "$part" > "$tmp"
            [ -s "$tmp" ]
            mv -T "$tmp" "$file"
          done
          touch /run/nx809j-rmtfs-ready
        '';
      };
      systemd.services.rmtfs = {
        wantedBy = [ "multi-user.target" ];
        unitConfig.ConditionPathExists = "/run/nx809j-rmtfs-ready";
        unitConfig.ConditionFileNotEmpty = map (f: "/var/lib/rmtfs/${f}") [
          "modem_fs1"
          "modem_fs2"
          "modem_fsc"
          "modem_fsg"
        ];
        serviceConfig = {
          ExecStart = "${pkgs.rmtfs}/bin/rmtfs -s -o /var/lib/rmtfs";
          # The remoteproc memory device is a character device. Even a bad
          # state-file symlink must never give this daemon a block device.
          DevicePolicy = "closed";
          DeviceAllow = [ "char-qcom_rmtfs_mem rw" ];
        };
      };
    };
}
