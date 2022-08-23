{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "screenshot";

      runtimeInputs = with pkgs; [

        ffmpeg
      ];

      text = builtins.readFile ./ex.sh;
    };

in
{
  environment.systemPackages = [
    script
  ];
}
