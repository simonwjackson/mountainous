# Everything every machine gets.
#
# This is the fleet standard. A host file holds only what is unique to that
# machine. Values a host may differ on are lib.mkDefault here.
{
  nixos.modules.base =
    { lib, pkgs, ... }:
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

      # Every x86 machine in the fleet is Intel. On another CPU the update is
      # simply not applied, so this costs nothing to be wrong about.
      hardware.cpu.intel.updateMicrocode = lib.mkDefault pkgs.stdenv.hostPlatform.isx86_64;

      # Compressed swap in RAM. A memory spike slows a machine down instead of
      # waking the OOM killer, and no host needs a swap partition for it.
      zramSwap.enable = lib.mkDefault true;

      # BBR instead of cubic. On the lossy Oracle -> home route (about 1.5%
      # loss at 100 ms) cubic fell to 0.3-0.7 MiB/s and BBR kept 14-15 MiB/s
      # (measured on Yari, 2026-10-13). On a clean LAN the two are alike.
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
        "net.core.default_qdisc" = lib.mkDefault "fq";
      };

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

      # Machines that move follow the clock where they are. The server layer
      # turns this off and pins UTC.
      services.automatic-timezoned.enable = lib.mkDefault true;
      services.timesyncd.enable = lib.mkDefault true;
      i18n.defaultLocale = "en_US.UTF-8";

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          # Key-only root. "no" blocks remote deploys entirely, which is how
          # hiyori ended up reachable only as simon with an interactive sudo.
          PermitRootLogin = "prohibit-password";
        };
        # SSH only over Tailscale. Every machine is on the tailnet, so nothing
        # needs port 22 on a LAN or the internet. If tailscaled fails, use the
        # console. Korri devices force it open (modules/korri.nix).
        openFirewall = lib.mkDefault false;
      };
      networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];

      networking.networkmanager.enable = true;

      # A default, so a product that fixes its own state version (Korri does)
      # decides it on the hosts that run that product.
      system.stateVersion = lib.mkDefault "25.05";
    };
}
