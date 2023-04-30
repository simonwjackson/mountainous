{ ... }:

{
  hardware.xpadneo.enable = true;

  programs.steam = {
    enable = true;
  };

  services.syncthing = {
    folders = {
      # gaming.path = "/storage/gaming";

      # gaming.devices = [ "unzen" "raiden" ];
    };
  };

  # "/home/simonwjackson/.local/share/Cemu/mlc01" = {
  #   device = "/storage/gaming/profiles/simonwjackson/progress/saves/wiiu/";
  #   options = [ "bind" ];
  # };
}

