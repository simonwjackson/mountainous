{
  lib,
  pkgs,
  writeShellApplication,
  ...
}: let
  secrets-encrypt = writeShellApplication {
    name = "secrets-encrypt";
    runtimeInputs = with pkgs; [git coreutils gnused gnugrep rage nix jq python3];
    text = ''
      # secrets encrypt - flag-driven secret authoring for the convention-based
      # secrets/ layout (see features/secrets/lib.nix).
      #
      # The relative path under secrets/ determines scope:
      #   <name>.age                       global, root-readable
      #   hosts/<host>/<name>.age          host-scoped
      #   user/<user>/[<sub>/]<name>.age   user-scoped
      #   system/<sub>/<name>.age          system-service-scoped
      #
      # Filename metadata (optional, all in the basename before .age):
      #   _o=<owner>   _g=<group>   _m=<mode>
      # e.g.  brave-api-key_o=simonwjackson_g=users.age

      usage() {
        cat <<'USAGE'
      Usage: secrets encrypt [OPTIONS] <relpath>

        <relpath>  Path under secrets/ for the new .age file. The leading
                   "secrets/" prefix and the ".age" suffix are both optional;
                   either will be stripped.

      Value source (exactly one required):
        --from-env <VAR>       Read value from environment variable
        --from-file <PATH>     Read value from file
        --from-stdin           Read value from stdin (until EOF)

      Options:
        --expose-as <VAR>      Also add VAR to presets/core/shell-secrets.nix
                               using the secret attr derived from <relpath>
        --shell-env <VAR>      Alias for --expose-as
        --force                Overwrite an existing .age file without asking
        --commit               git commit after staging
        -h, --help             Show this help

      Examples:
        # user-scoped credential, value from env
        secrets encrypt user/simonwjackson/credentials/openai-api-key \
          --from-env OPENAI_API_KEY \
          --expose-as OPENAI_API_KEY

        # global, decrypted file owned by simonwjackson:users
        printf '%s' "$KEY" | secrets encrypt \
          'brave-api-key_o=simonwjackson' --from-stdin

        # from a plaintext file
        secrets encrypt user/simonwjackson/credentials/master \
          --from-file ~/master.txt --commit
      USAGE
      }

      die() { echo "❌ $*" >&2; exit 1; }

      relpath=""
      source_kind=""
      source_arg=""
      force=0
      do_commit=0
      expose_env=""

      while [ $# -gt 0 ]; do
        case "$1" in
          --from-env)    source_kind="env";    source_arg="''${2:-}"; shift 2 ;;
          --from-file)   source_kind="file";   source_arg="''${2:-}"; shift 2 ;;
          --from-stdin)  source_kind="stdin";  source_arg="";          shift   ;;
          --expose-as|--shell-env)
                          expose_env="''${2:-}";                       shift 2 ;;
          --force)       force=1;                                      shift   ;;
          --commit)      do_commit=1;                                  shift   ;;
          -h|--help)     usage; exit 0 ;;
          --) shift; break ;;
          -*) die "Unknown option: $1 (use --help for usage)" ;;
          *)
            [ -z "$relpath" ] || die "Multiple paths given: '$relpath' and '$1'"
            relpath="$1"; shift
            ;;
        esac
      done

      [ -n "$relpath" ]      || { usage >&2; exit 1; }
      [ -n "$source_kind" ]  || die "Must specify one of --from-env / --from-file / --from-stdin"
      if [ -n "$expose_env" ] && ! [[ "$expose_env" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
        die "--expose-as expects an env-var name like OPENAI_API_KEY, got '$expose_env'"
      fi

      # ── Locate repo & secrets dir ────────────────────────────────────
      git_root=$(git rev-parse --show-toplevel 2>/dev/null) \
        || die "Not inside a git repository"
      secrets_dir="$git_root/secrets"
      rules_file="$secrets_dir/default.nix"
      [ -d "$secrets_dir" ] || die "secrets/ not found at $secrets_dir"
      [ -f "$rules_file" ]  || die "secrets/default.nix (agenix rules) not found"

      # ── Normalize relpath ────────────────────────────────────────────
      # Strip optional "secrets/" prefix and ".age" suffix so callers can
      # paste either form.
      relpath="''${relpath#secrets/}"
      relpath="''${relpath%.age}"

      case "$relpath" in
        ""|/*|*/) die "Invalid relpath: '$relpath'" ;;
        *..*) die "relpath must not contain '..': '$relpath'" ;;
      esac

      basename="''${relpath##*/}"
      # The discovery library splits on '_' and treats '<k>=<v>' segments as
      # metadata. The bare name parts must match [A-Za-z0-9._-]+.
      name_check="''${basename//_*=*/}"
      case "$name_check" in
        *[!A-Za-z0-9._-]*) die "Invalid characters in filename: '$basename' (allowed: A-Z a-z 0-9 . _ -, plus _<k>=<v> tags)" ;;
      esac

      target="$secrets_dir/$relpath.age"
      target_dir="''${target%/*}"

      # Derive the config.age.secrets attr name exactly like
      # features/secrets/lib.nix:
      #   root/global:                         <name>
      #   hosts/<host>/<name>:                 <name>
      #   user/<user>/<sub>/.../<name>:        <sub>-...-<name>
      #   system/<sub>/<name>:                 <name>
      parsed_name_parts=()
      IFS='_' read -r -a basename_parts <<< "$basename"
      for part in "''${basename_parts[@]}"; do
        case "$part" in
          *=*) ;;
          *) parsed_name_parts+=("$part") ;;
        esac
      done
      [ "''${#parsed_name_parts[@]}" -gt 0 ] || die "Could not derive a secret name from '$basename'"
      parsed_name=$(IFS=_; echo "''${parsed_name_parts[*]}")
      secret_attr="$parsed_name"
      if [[ "$relpath" == user/* ]]; then
        rel_dir="''${relpath%/*}"
        IFS='/' read -r -a dir_parts <<< "$rel_dir"
        if [ "''${#dir_parts[@]}" -gt 2 ]; then
          prefix_parts=("''${dir_parts[@]:2}")
          prefix=$(IFS=-; echo "''${prefix_parts[*]}")
          secret_attr="$prefix-$parsed_name"
        fi
      fi

      # ── Refuse to overwrite without --force ──────────────────────────
      if [ -e "$target" ] && [ "$force" -ne 1 ]; then
        die "Refusing to overwrite existing $target (pass --force to allow)"
      fi

      # ── Collect the secret value ─────────────────────────────────────
      case "$source_kind" in
        env)
          [ -n "$source_arg" ] || die "--from-env requires a variable name"
          # ''${!VAR} indirect expansion; require the variable to be exported.
          if ! printenv "$source_arg" >/dev/null 2>&1; then
            die "Environment variable '$source_arg' is unset"
          fi
          secret_value=$(printenv "$source_arg")
          [ -n "$secret_value" ] || die "Environment variable '$source_arg' is empty"
          ;;
        file)
          [ -n "$source_arg" ] || die "--from-file requires a path"
          [ -r "$source_arg" ] || die "Cannot read file: $source_arg"
          secret_value=$(cat -- "$source_arg")
          ;;
        stdin)
          secret_value=$(cat)
          [ -n "$secret_value" ] || die "Empty value on stdin"
          ;;
      esac

      # ── Encrypt ──────────────────────────────────────────────────────
      # We avoid `agenix -e` here because its edit flow tries to decrypt the
      # target before invoking $EDITOR, which fails for files that don't yet
      # exist (and they can't exist before encrypt because secrets/default.nix
      # discovers .age files via readDir at eval time). Instead, extract the
      # recipient set from the rules and pipe through `rage` directly.
      #
      # Every entry in secrets/default.nix shares the same `allKeys` recipient
      # list, so we read it off any existing rule and reuse it. If the repo
      # ever introduces per-file recipient sets, this must read the rule
      # specific to the new path (which won't exist yet — see chicken/egg
      # above; the rules file would also need a way to predict the new path).
      mkdir -p -- "$target_dir"

      echo "🔓 Resolving recipients from secrets/default.nix…"
      # shellcheck disable=SC2016  # literal ''${...} is for nix, not bash
      recipients_json=$(
        cd "$git_root"
        nix eval --json --impure --expr '
          let
            rules = import ./secrets/default.nix;
            names = builtins.attrNames rules;
          in
            if names == []
            then throw "secrets/default.nix has no entries; cannot derive recipients"
            else rules."''${builtins.head names}".publicKeys
        '
      ) || die "Failed to evaluate secrets/default.nix for recipients"

      mapfile -t recipients < <(printf '%s' "$recipients_json" | jq -r '.[]')
      [ "''${#recipients[@]}" -gt 0 ] || die "No recipients resolved from rules"

      rage_args=()
      for r in "''${recipients[@]}"; do rage_args+=(-r "$r"); done

      echo "🔐 Encrypting → $target  (''${#recipients[@]} recipients)"
      printf '%s' "$secret_value" | rage -e "''${rage_args[@]}" -o "$target"

      # ── Optional shell exposure ──────────────────────────────────────
      staged_paths=("$target")
      if [ -n "$expose_env" ]; then
        shell_secrets_file="$git_root/presets/core/shell-secrets.nix"
        echo "🐚 Exposing $expose_env via mountainous.features.shell-secrets ($secret_attr)"
        SHELL_SECRETS_FILE="$shell_secrets_file" \
        EXPOSE_ENV="$expose_env" \
        EXPOSE_SECRET="$secret_attr" \
          python3 - <<'PY'
      import os
      import re
      from pathlib import Path

      path = Path(os.environ["SHELL_SECRETS_FILE"])
      env_name = os.environ["EXPOSE_ENV"]
      secret_attr = os.environ["EXPOSE_SECRET"]

      entries = {}
      if path.exists():
          text = path.read_text()
          for match in re.finditer(r'^\s*([A-Z_][A-Z0-9_]*)\s*=\s*"([^"]+)";\s*$', text, re.MULTILINE):
              entries[match.group(1)] = match.group(2)

      entries[env_name] = secret_attr
      path.parent.mkdir(parents=True, exist_ok=True)
      path.write_text(
          "{\n"
          + "".join(f'  {key} = "{entries[key]}";\n' for key in sorted(entries))
          + "}\n"
      )
      PY
        staged_paths+=("$shell_secrets_file")
      fi

      # ── Stage (and optionally commit) ────────────────────────────────
      # Nix flakes only see git-tracked files; staging is non-optional.
      git -C "$git_root" add -- "''${staged_paths[@]}"
      printf '✅ Staged %s\n' "''${staged_paths[@]}"

      if [ "$do_commit" -eq 1 ]; then
        git -C "$git_root" commit -m "secrets: add $relpath" \
          -m "Encrypted via secrets-encrypt."
      else
        echo "ℹ️  Not committed. Run 'git commit' when ready, or pass --commit next time."
      fi
    '';
  };

  secrets-wrapper = writeShellApplication {
    name = "secrets";
    runtimeInputs = [secrets-encrypt];
    text = ''
      if [ $# -eq 0 ]; then
        cat <<'USAGE'
      Usage: secrets <command> [args...]

      Commands:
        encrypt    Encrypt a new secret (see 'secrets encrypt --help')

      For re-encrypting all existing secrets, use 'just rekey'.
      USAGE
        exit 1
      fi

      cmd="$1"; shift
      case "$cmd" in
        encrypt) exec secrets-encrypt "$@" ;;
        rekey)
          echo "ℹ️  'secrets rekey' has moved to 'just rekey' (uses your local SSH keys)." >&2
          exit 2
          ;;
        -h|--help|help)
          exec "$0"  # re-print usage
          ;;
        *) echo "❌ Unknown command: $cmd" >&2; exit 1 ;;
      esac
    '';
  };
in
  pkgs.symlinkJoin {
    name = "secrets";
    paths = [secrets-wrapper secrets-encrypt];
    meta = {
      description = "Convention-based agenix secret authoring for mountainous";
      mainProgram = "secrets";
      platforms = lib.platforms.unix;
      license = lib.licenses.mit;
    };
  }
