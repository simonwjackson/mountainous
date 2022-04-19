{ config, pkgs, ... }:

let
  script1 = pkgs.writeShellApplication {
    name = "vimwiki-index";
    runtimeInputs = with pkgs; [ neovim ];
    text = builtins.readFile ./vimwiki-index.sh;
  };

  script2 = pkgs.writeShellApplication {
    name = "vimwiki-inbox";
    runtimeInputs = with pkgs; [ neovim ];
    text = builtins.readFile ./vimwiki-inbox.sh;
  };

in
{
  home.packages = [
    script1
    script2
  ];
}
