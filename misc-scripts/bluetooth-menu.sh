# Define the icons for connected and disconnected devices using Nerd Fonts
ICON_CONNECTED="󰂱"
ICON_DISCONNECTED="󰂱"

# List paired devices and their connection status using bluetoothctl
paired_devices=$(bluetoothctl devices | grep -o -E '([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}')
# Display devices in fzf with connection status

selected_device=$(
echo "$paired_devices" \
  | while read -r addr; do
  device_info=$(bluetoothctl info "$addr")
  device_name=$(echo "$device_info" | grep "Name:" | awk -F': ' '{print $2}')
  device_connected=$(echo "$device_info" | grep "Connected:" | awk -F': ' '{print $2}')

  if [ "$device_connected" = "yes" ]; then
    echo -e "$ICON_CONNECTED\t$device_name\t$addr"
  else
    echo -e "\t$device_name\t$addr"
  fi
done \
  | fzf --with-nth=1,2 --delimiter=' ' \
  | awk -F'\t' '{print $NF}'
)

# Toggle the selected device's connection status
if [ -n "$selected_device" ]; then
  current_status=$(bluetoothctl info "$selected_device" | grep "Connected:" | awk -F': ' '{print $2}')
  if [ "$current_status" = "yes" ]; then
    bluetoothctl disconnect "$selected_device"
  else
    bluetoothctl connect "$selected_device"
  fi
else
  echo "No device selected"
fi
