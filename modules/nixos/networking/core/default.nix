{lib, ...}: {
  networking = {
    useDHCP = lib.mkDefault true;
    domain = "mountaino.us";
    networkmanager.enable = true; # Easiest to use and most distros use this by default.
  };
}
