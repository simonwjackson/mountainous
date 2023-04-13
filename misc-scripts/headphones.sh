HEADPHONE_MAC_1="CC:98:8B:93:2A:1F"
HEADPHONE_MAC_2="YY:YY:YY:YY:YY:YY"

dbus-monitor --system "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',arg0='org.bluez.Device1'" |
  while read -r line; do
    if echo $line | grep -q -E "hci0/dev_$(echo $HEADPHONE_MAC_1 | tr ':' '_')|hci0/dev_$(echo $HEADPHONE_MAC_2 | tr ':' '_')"; then
      if echo $line | grep -q -E "Connected'; true"; then
        echo ""
      elif echo $line | grep -q -E "Connected'; false"; then
        echo ""
      fi
    fi
  done
