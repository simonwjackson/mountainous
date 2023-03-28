{ config, pkgs, modulesPath, lib, ... }:

let
  rofi-server = with pkgs; rustPlatform.buildRustPackage {
    pname = "mle";
    version = "1.5.0";

    src = ./.;

    # Use select(2) instead of poll(2) (poll is returning POLLINVAL on macOS)
    # Enable compiler optimization
    # CFLAGS = "-DTB_OPT_SELECT -O2";

    # nativeBuildInputs = [ makeWrapper installShellFiles ];

    buildInputs = [
      rustc
      cargo
    ];

    doCheck = true;

    cargoLock = {
      lockFile = ./Cargo.lock;
    };

  };
in
{
  systemd.user.services = {
    rofi-server = {
      Unit = {
        Description = "Server backend for rofi-firefox-tabs";
      };
      Service = {
        StandardOutput = "journal";
        ExecStart = "%h/.nix-profile/bin/rofi-server";
        Restart = "always";
        RestartSec = "5";
        Type = "simple";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };
  };
  home.packages = [
    rofi-server
  ];
}
