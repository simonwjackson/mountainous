if nmcli dev status | grep -q 'wifi\s*connected'
then
  echo ""
elif nmcli dev status | grep -q 'gsm\s*connected'
then
  echo "說"
else 
  echo ""
fi
