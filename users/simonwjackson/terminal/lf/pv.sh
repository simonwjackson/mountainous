#!/run/current-system/sw/bin/bash

case "$1" in
    *.tar*) tar tf "$1";;
    *.zip) unzip -l "$1";;
    *.rar) unrar l "$1";;
    *.7z) 7z l "$1";;
    *.pdf) pdftotext "$1" -;;
    *) "${HOME}/.nix-profile/bin/bat" --style=plain --color=always --theme=dracula "$1" || cat "$1";;
esac

