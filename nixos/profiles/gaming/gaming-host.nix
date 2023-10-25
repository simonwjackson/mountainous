{
  config,
  pkgs,
  ...
}: {
  imports = [
    ./gaming.nix
  ];

  systemd.user.services.startSteam = {
    path = with pkgs; [flatpak];
    description = "Start Steam Flatpak app";
    wantedBy = ["graphical-session.target"];
    partOf = ["graphical-session.target"];
    after = ["mountSteamAppsOverlay.service"];
    serviceConfig = {
      ExecStart = "${pkgs.flatpak}/bin/flatpak run com.valvesoftware.Steam";
      Restart = "on-failure";
    };
  };
}
