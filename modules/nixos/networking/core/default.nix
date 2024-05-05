{lib, ...}: {
  networking = {
    useDHCP = lib.mkDefault true;
    domain = "mountaino.us";
    networkmanager.enable = true;
  };

  # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
  systemd.services.NetworkManager-wait-online.enable = false;
}
