# Everything every machine gets.
{
  nixos.modules.base =
    { lib, ... }:
    {
      # The defaults here describe a machine that stays where it is put: a
      # loader entry in NVRAM, written by the machine it belongs to. The
      # portable layer overrides both, because a stick must not edit the
      # firmware of a laptop it is only visiting. Fixed is the norm; portable
      # is the deviation.
      boot.loader.systemd-boot.enable = lib.mkDefault true;
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

      # There is no hardware-configuration.nix anywhere in this tree, so the
      # baseline that nixos-generate-config would have written has to live
      # somewhere. This is the set needed to reach a root filesystem and type
      # a passphrase on any machine built this decade. The portable layer adds
      # the controllers a stick may meet on hardware it has never seen.
      boot.initrd.availableKernelModules = [
        "nvme"
        "ahci"
        "sd_mod"
        "xhci_pci"
        "usbhid"
      ];

      # Drivers are useless without the blobs they load at probe time.
      #
      # This was in the portable layer, where it read as a portability
      # concern. It is not one. Without it an Intel Iris Xe GPU fails to
      # initialise and opening /dev/dri/cardN returns EINVAL, which looks like
      # a compositor bug and is not one. That is true of an internal disk as
      # much as a stick, so a host that does not import `portable` must not
      # lose it.
      hardware.enableRedistributableFirmware = true;

      # Also moved out of `portable`. Flash wears out whether it is soldered
      # to a board or hanging off a USB port.
      services.fstrim.enable = true;
      boot.tmp.useTmpfs = true;
      nix.settings.auto-optimise-store = true;

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        trusted-users = [ "@wheel" ];
      };

      time.timeZone = lib.mkDefault "America/New_York";
      i18n.defaultLocale = "en_US.UTF-8";

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          # Key-only root. "no" blocks remote deploys entirely, which is how
          # ridge ended up reachable only as simon with an interactive sudo.
          PermitRootLogin = "prohibit-password";
        };
      };

      networking.networkmanager.enable = true;

      system.stateVersion = "25.05";
    };
}
