{ config, pkgs, ... }:

let
  wikis = pkgs.writeShellApplication
    {
      name = "wikis";
      runtimeInputs = with pkgs; [ fzf ];
      text = ''
        sed -n 's/^let \(.*\).path = \(.*\)/\1 \2/p' \
        < "/home/simonwjackson/.config/nvim/init.vim" \
        | fzf --with-nth 1 \
        | cut -d ' ' -f 2  \
        | xargs -I '___' nvim -c "cd ___ | VimwikiIndex"
      '';
    };

in
{
  home.packages = [
    wikis
  ];
}
