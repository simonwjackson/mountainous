speed=$(surface profile get)

case "${speed}" in
  low-power)
    echo 
  ;;
  balanced)
    echo 廒
  ;;
  balanced-performance)
    echo ﰌ
  ;;
  performance)
    echo 省
  ;;
esac
