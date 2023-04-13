# Save the current window focus
focused_win=$(xdotool getwindowfocus)

# Apply a darkening rule to other windows, wallpaper, and wibar using picom
picom-trans -c -w $kitty_win_id 80

# Wait until the centered kitty window is closed
while xdotool search --class "floater" >/dev/null 2>&1; do
  sleep 0.5
done

# Reset the transparency of other windows, wallpaper, and wibar
picom-trans -c -w $focused_win -r

# Return focus to the previously focused window
xdotool windowactivate $focused_win
