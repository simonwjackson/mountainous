{ config, pkgs, ... }:

let
  refreshRate = "120.0";
  nativeResolution = "2880x1920";
  monitor = "eDP-1";

  scaleDesktop = pkgs.writeShellApplication
    {
      name = "scale-desktop";

      runtimeInputs = with pkgs; [
        xorg.xrandr
        fzf
      ];

      text = ''
        # monitor=$(xrandr --listactivemonitors | awk '{print $4}' | sed '/^$/d' | fzf --select-1)
        scale=$(printf ".5\n1\n1.125\n1.25\n1.333333\n1.5\n1.66666\n1.75\n1.875\n2" | fzf)

        mkdir -p "$HOME/.local/share/desktop"
        touch "$HOME/.local/share/desktop/scale"

        echo "$scale" > "$HOME/.local/share/desktop/scale"

        xrandr --output "${monitor}" --mode ${nativeResolution} --scale "$scale" --rate ${refreshRate}
      '';
    };

in
{
  home.packages = [
    scaleDesktop
  ];
}
