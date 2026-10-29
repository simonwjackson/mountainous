# Contract 2. Validate before contacting Hyprland; interpolate only tokens from
# these closed alphabets, never arbitrary shell text into Lua source.
usage() {
  echo 'usage: mountainous-page-layout page ID [cap=N] [floating=BOOL] [gap=N] [zen=BOOL] | page-default ID FIELD | default CONNECTOR [cap=N] [floating=BOOL] [gap=N] | reset CONNECTOR | step-gap ID DELTA | toggle-floating ID' >&2
  exit 2
}
page_id() {
  if [[ "$1" == active ]]; then target='"active"'
  elif [[ "$1" =~ ^[1-9][0-9]*$ ]]; then target="$1"
  else usage; fi
}
connector() {
  [[ "$1" =~ ^[A-Za-z0-9_.:-]+$ ]] || usage
  target="\"$1\""
}
settings() {
  local allow_zen="$1" item key value seen=' '
  shift
  fields=''
  for item in "$@"; do
    [[ "$item" == *=* ]] || usage
    key="${item%%=*}"; value="${item#*=}"
    [[ "$seen" != *" $key "* ]] || usage
    seen+="$key "
    case "$key" in
      cap) [[ "$value" =~ ^[123]$ ]] || usage ;;
      floating) [[ "$value" == true || "$value" == false ]] || usage ;;
      zen) [[ "$allow_zen" == yes && ( "$value" == true || "$value" == false ) ]] || usage ;;
      gap) [[ "$value" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || usage ;;
      *) usage ;;
    esac
    fields+="$key=$value,"
  done
}
[[ $# -ge 2 ]] || usage
operation="$1"; subject="$2"; shift 2
case "$operation" in
  page)
    page_id "$subject"; settings yes "$@"
    call="page($target,{$fields})" ;;
  page-default)
    [[ $# -eq 1 ]] || usage
    page_id "$subject"
    case "$1" in cap|floating|gap|all) ;; *) usage ;; esac
    call="page_default($target,\"$1\")" ;;
  default)
    connector "$subject"; settings no "$@"
    call="default($target,{$fields})" ;;
  reset)
    [[ $# -eq 0 ]] || usage
    connector "$subject"; call="reset($target)" ;;
  step-gap)
    [[ $# -eq 1 && "$1" =~ ^-?[0-9]+([.][0-9]+)?$ ]] || usage
    page_id "$subject"; call="step_gap($target,$1)" ;;
  toggle-floating)
    [[ $# -eq 0 ]] || usage
    page_id "$subject"; call="toggle_floating($target)" ;;
  *) usage ;;
esac
# hyprctl can exit zero after a Lua error. Its eval success response is "ok";
# reject every other reply, including missing pages and disconnected monitors.
reply=$(hyprctl --instance 0 eval "require(\"page-layout\").$call")
if [[ "$reply" != ok ]]; then
  printf '%s\n' "$reply" >&2
  exit 1
fi
