{ pkgs, ... }: {
  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the Plasma 5 Desktop Environment.
  services.xserver.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma5.enable = true;

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-kde
    ];
  };

  services.unclutter = {
    enable = true;
    extraOptions = [
      "exclude-root"
      "ignore-scrolling"
    ];
  };
}
