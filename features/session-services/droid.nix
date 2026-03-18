{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStringsSep escapeShellArg filterAttrs mkAfter mkIf optionalString;

  enabledServices = filterAttrs (_: service: service.enable) config.mountainous.features.session-services;
  enabledServiceNames = builtins.attrNames enabledServices;
  hasEnabledServices = enabledServiceNames != [];

  mkEnvironmentExports = environment:
    concatMapStringsSep "\n" (name: "export ${name}=${escapeShellArg environment.${name}}") (builtins.attrNames environment);

  expectedBinaryFor = command: let
    match = builtins.match "^([^[:space:]]+)([[:space:]].*)?$" command;
  in
    if match == null
    then command
    else builtins.elemAt match 0;

  mkServiceCase = name: service: ''
    ${escapeShellArg name})
      state_dir=${escapeShellArg service.stateDir}
      command=${escapeShellArg service.command}
      expected_binary=${escapeShellArg (expectedBinaryFor service.command)}
      startup=${escapeShellArg service.startup}
      validate_command=${escapeShellArg (if service.validateCommand == null then "" else service.validateCommand)}
      ${optionalString (builtins.attrNames service.environment != []) (mkEnvironmentExports service.environment)}
      ;;
  '';

  initExtra = concatMapStringsSep "\n" (name: ''
    ${serviceEnsure}/bin/service-ensure ${escapeShellArg name}
    (${pkgs.coreutils}/bin/sleep 3; ${serviceEnsure}/bin/service-ensure ${escapeShellArg name} >/dev/null 2>&1 || true) >/dev/null 2>&1 &
    disown "$!" 2>/dev/null || true
  '') enabledServiceNames;

  serviceEnsure = pkgs.writeShellScriptBin "service-ensure" ''
    set -euo pipefail

    readonly COREUTILS_BIN=${pkgs.coreutils}/bin
    readonly AWK_BIN=${pkgs.gawk}/bin/awk
    readonly BASH_BIN=${pkgs.bash}/bin/bash

    service_name="''${1:-}"
    if [[ -z "$service_name" ]]; then
      printf 'usage: service-ensure <service-name>\n' >&2
      exit 1
    fi

    state_dir=""
    command=""
    expected_binary=""
    startup=""
    validate_command=""

    case "$service_name" in
    ${concatMapStringsSep "\n" (name: mkServiceCase name enabledServices.${name}) enabledServiceNames}
      *)
        printf 'unknown session service: %s\n' "$service_name" >&2
        exit 1
        ;;
    esac

    lock_dir="$state_dir/lock"
    lock_pid_file="$lock_dir/pid"
    state_file="$state_dir/state"

    cleanup_lock() {
      "$COREUTILS_BIN"/rm -f "$lock_pid_file"
      "$COREUTILS_BIN"/rmdir "$lock_dir" 2>/dev/null || true
    }

    acquire_lock() {
      local wait_loops=0
      "$COREUTILS_BIN"/mkdir -p "$state_dir"

      while ! "$COREUTILS_BIN"/mkdir "$lock_dir" 2>/dev/null; do
        if [[ -f "$lock_pid_file" ]]; then
          local lock_owner
          lock_owner="$(<"$lock_pid_file")"
          if [[ -n "$lock_owner" ]] && kill -0 "$lock_owner" 2>/dev/null; then
            exit 0
          fi

          "$COREUTILS_BIN"/rm -rf "$lock_dir"
          continue
        fi

        wait_loops=$((wait_loops + 1))
        if (( wait_loops >= 20 )); then
          "$COREUTILS_BIN"/rm -rf "$lock_dir"
          wait_loops=0
          continue
        fi

        "$COREUTILS_BIN"/sleep 0.1
      done

      printf '%s\n' "$$" > "$lock_pid_file"
      trap cleanup_lock EXIT
    }

    read_starttime() {
      local pid="$1"
      "$AWK_BIN" 'NR == 1 { print $22 }' "/proc/$pid/stat" 2>/dev/null || true
    }

    read_cmdline() {
      local pid="$1"
      "$COREUTILS_BIN"/tr '\000' ' ' < "/proc/$pid/cmdline" 2>/dev/null || true
    }

    read_exe() {
      local pid="$1"
      "$COREUTILS_BIN"/readlink -f "/proc/$pid/exe" 2>/dev/null || true
    }

    is_tracked_process() {
      local pid="$1"
      local starttime="$2"
      local tracked_binary="$3"
      local current_starttime
      local current_cmdline
      local current_exe

      [[ -n "$pid" ]] || return 1
      [[ -d "/proc/$pid" ]] || return 1

      current_starttime="$(read_starttime "$pid")"
      [[ -n "$current_starttime" ]] || return 1
      [[ "$current_starttime" == "$starttime" ]] || return 1

      current_exe="$(read_exe "$pid")"
      if [[ -n "$tracked_binary" ]] && [[ "$current_exe" == "$tracked_binary" ]]; then
        return 0
      fi

      current_cmdline="$(read_cmdline "$pid")"
      [[ -n "$current_cmdline" ]] || return 1

      case "$current_cmdline" in
        "$expected_binary"|"$expected_binary "*)
          return 0
          ;;
        *)
          return 1
          ;;
      esac
    }

    is_valid_service() {
      local pid="$1"
      local starttime="$2"
      local tracked_binary="$3"

      is_tracked_process "$pid" "$starttime" "$tracked_binary" || return 1

      if [[ -n "$validate_command" ]]; then
        "$BASH_BIN" -lc "$validate_command" || return 1
      fi

      return 0
    }

    stop_service() {
      local pid="$1"

      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        "$COREUTILS_BIN"/sleep 1

        if kill -0 "$pid" 2>/dev/null; then
          kill -9 "$pid" 2>/dev/null || true
        fi
      fi

      "$COREUTILS_BIN"/rm -f "$state_file"
    }

    start_service() {
      local pid
      local starttime
      local binary_path
      local attempt=1
      local max_attempts=20

      printf 'starting session service: %s\n' "$service_name" >&2

      while (( attempt <= max_attempts )); do
        (
          exec "$BASH_BIN" -lc "exec $command"
        ) >/dev/null 2>&1 &
        pid=$!

        "$COREUTILS_BIN"/sleep 0.3

        if kill -0 "$pid" 2>/dev/null; then
          starttime="$(read_starttime "$pid")"
          binary_path="$("$COREUTILS_BIN"/readlink -f "/proc/$pid/exe" 2>/dev/null || printf '%s' "$expected_binary")"

          {
            printf 'PID=%q\n' "$pid"
            printf 'STARTTIME=%q\n' "$starttime"
            printf 'BINARY=%q\n' "$binary_path"
          } > "$state_file"
          return 0
        fi

        attempt=$((attempt + 1))
        "$COREUTILS_BIN"/sleep 0.5
      done

      printf 'failed to start session service: %s\n' "$service_name" >&2
      "$COREUTILS_BIN"/rm -f "$state_file"
      exit 1
    }

    acquire_lock

    PID=""
    STARTTIME=""
    BINARY=""
    if [[ -f "$state_file" ]]; then
      # shellcheck disable=SC1090
      source "$state_file"
    fi

    case "$startup" in
      once)
        if [[ -f "$state_file" ]]; then
          exit 0
        fi
        start_service
        ;;
      always-restart)
        if is_tracked_process "$PID" "$STARTTIME" "$BINARY"; then
          stop_service "$PID"
        else
          "$COREUTILS_BIN"/rm -f "$state_file"
        fi
        start_service
        ;;
      ensure-running)
        if is_valid_service "$PID" "$STARTTIME" "$BINARY"; then
          exit 0
        fi

        if is_tracked_process "$PID" "$STARTTIME" "$BINARY"; then
          stop_service "$PID"
        else
          "$COREUTILS_BIN"/rm -f "$state_file"
        fi

        start_service
        ;;
      *)
        printf 'unknown startup mode: %s\n' "$startup" >&2
        exit 1
        ;;
    esac
  '';
in {
  config = mkIf hasEnabledServices {
    environment.packages = [serviceEnsure];

    home-manager.config.programs.bash.initExtra = mkAfter initExtra;
  };
}
