{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    programs.mpv = {
      enable = true;

      config = {
        af = "equalizer=f=1000:width_type=h:width=200:g=-2,equalizer=f=2000:width_type=h:width=200:g=-4,equalizer=f=4000:width_type=h:width=200:g=-6,equalizer=f=8000:width_type=h:width=200:g=-8,equalizer=f=16000:width_type=h:width=200:g=-10";
      };
    };
  };
}
