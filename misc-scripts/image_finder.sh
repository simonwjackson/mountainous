#! /usr/bin/env nix-shell
#! nix-shell -i bash -p python38Packages.ueberzug fzf

IMAGE_DIR="$HOME/downloads" # Replace with your image directory

function kitty_image_preview() {
  local image_path="$1"
  if [[ -n "$image_path" ]]; then
    printf "Displaying image: %s\n" "$image_path"
    # Use Kitty's Terminal graphics protocol for image preview
    kitty +kitten icat --align=left --place=40x20@1x1 "$image_path"
  fi
}

export -f kitty_image_preview

find "$IMAGE_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.gif" \) | fzf --preview 'bash -c "kitty_image_preview {}"'
