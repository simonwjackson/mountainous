{ config, pkgs, ... }:

let
  script = pkgs.writeShellApplication
    {
      name = "ex";

      runtimeInputs = with pkgs; [
        unzip
        p7zip
      ];

      text = builtins.readFile ./ex.sh;
    };

in
{
  environment.systemPackages = [
    script
  ];
}
