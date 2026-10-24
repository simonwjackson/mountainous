# All paths are pinned by writeShellApplication. Do not let a preference or
# art-generation failure prevent locking. Keep the mutex until hyprlock exits.
umask 077
conf=@fallback@
if [[ -n "${XDG_RUNTIME_DIR:-}" ]] && mkdir -p "$XDG_RUNTIME_DIR/mountainous-lock"; then
  if { exec 9>"$XDG_RUNTIME_DIR/mountainous-lock/lock"; }; then
    # A second request must not replace the first request's generated files.
    if flock -n -E 75 9; then
      if generated=$(python3 @configure@ --art @art@ "$@"); then
        conf="$generated"
      else
        echo 'mountainous-lock: configuration failed; using static fallback' >&2
      fi
    elif [[ $? -eq 75 ]]; then
      exit 0
    else
      echo 'mountainous-lock: mutex failed; using static fallback' >&2
    fi
  fi
fi
if hyprlock --config "$conf"; then
  exit 0
fi
# Config parsing and resource loading can fail inside hyprlock too.
echo 'mountainous-lock: hyprlock failed; retrying static fallback' >&2
exec hyprlock --config @fallback@
