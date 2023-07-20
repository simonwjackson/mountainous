{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    systemd.user.services.autorandr = {
      Unit = {
        Description = "autorandr";
        After = "graphical-session.target";
      };
      Service = {
        Type = "oneshot";
        Environment = "DISPLAY=:0";
        ExecStart = "${pkgs.autorandr}/bin/autorandr --change";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
    };

    programs.autorandr = {
      enable = true;
      profiles = {
        default = {
          fingerprint = {
            eDP-1 = "00ffffffffffff004c83674100000000001f0104b51d1378020cf1ae523cb9230c505400000001010101010101010101010101010101c3804050b00838700820680821ba1000001bc3804050b00838700820680821ba1000001b000000fe0053444320202020202020202020000000fe0041544e413333414130322d3020019302030f00e3058000e606050174600700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b7";
            eDP-2 = "00ffffffffffff004c83824100000000001f0104b51d1378020cf1ae523cb9230c505400000001010101010101010101010101010101c3804050b00838700820680821ba1000001bc3804050b00838700820680821ba1000001b000000fe0053444320202020202020202020000000fe0041544e413333414130362d3020017402030f00e3058000e606050174600700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b7";
          };
          config = {
            eDP-1 = {
              enable = true;
              crtc = 0;
              mode = "2880x1800";
              position = "0x0";
              primary = true;
              rate = "60.00";
              rotate = "inverted";
            };
            eDP-2 = {
              enable = true;
              crtc = 1;
              mode = "2880x1800";
              position = "0x1800";
              rate = "60.00";
            };
          };
        };
      };
    };
  };
}
