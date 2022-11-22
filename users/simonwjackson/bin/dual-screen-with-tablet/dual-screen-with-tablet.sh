xrandr --newmode "2048x2732_60.00"  483.25  2048 2224 2448 2848  2732 2735 2745 2829 -hsync +vsync
xrandr --addmode VIRTUAL1 2048x2732_60.00
xrandr \
    --output DP1 --mode 1920x1080 --pos 0x0 --rotate normal \
    --output DP2 --off \
    --output HDMI1 --off \
    --output HDMI2 --primary --mode 1920x1080 --pos 3968x0 --rotate normal \
    --output HDMI3 --off \
    --output VIRTUAL1 --mode 2048x2732_60.00 --pos 1920x0 --rotate normal \
    --output VIRTUAL2 --off
