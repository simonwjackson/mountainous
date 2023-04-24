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
            DP-1 = "00ffffffffffff000f330716020000002d200104b53d00782f57a1b33333cc14145054210800d100b3009500810001010101010101019c6800a0a04029603020350068be1000001a3ad100a0a04029603020350068be1000001a000000fc0041534d2d31363051430a202020000000fd0030a5c8c841010a202020202020016d02032ef2459001020304e200d523097f0783010000e305c000e60605016262006dd85dc4018200000000000000006a5e00a0a0a029503020350068be1000001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ce";
            DP-2 =
              "00ffffffffffff000f330716020000002d200104b53d00782f57a1b33333cc14145054210800d100b3009500810001010101010101019c6800a0a04029603020350068be1000001a3ad100a0a04029603020350068be1000001a000000fc0041534d2d31363051430a202020000000fd0030a5c8c841010a202020202020016d02032ef2459001020304e200d523097f0783010000e305c000e60605016262006dd85dc4018200000000000000006a5e00a0a0a029503020350068be1000001e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000ce";
          };
          config = {
            DP-1 = {
              crtc = 0;
              mode = "2560x1600";
              position = "0x0";
              primary = true;
              rate = "120.00";
            };
            DP-2 = {
              crtc = 1;
              mode = "2560x1600";
              position = "0x1600";
              rate = "120.00";
            };
          };
        };
      };
    };
  };
}
