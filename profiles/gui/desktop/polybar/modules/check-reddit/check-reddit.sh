URL="https://www.reddit.com/message/unread/.json?feed=82596639a1159b97a2660514382e7bac7cf722d7&user=simonwjackson"
USERAGENT="polybar-scripts/notification-reddit:v1.0 u/simonwjackson"

notifications=$(curl -sf --user-agent "$USERAGENT" "$URL" | jq '.["data"]["children"] | length')

if [ -n "$notifications" ] && [ "$notifications" -gt 0 ]; then
  echo " $notifications"
else
  echo ""
fi
