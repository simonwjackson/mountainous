{
  networking.networkmanager.enable = true; # Easiest to use and most distros use this by default.

  # WARN: This speeds up `nixos-rebuild`, but im not sure if there are any side effects
  systemd.services.NetworkManager-wait-online.enable = false;
}
