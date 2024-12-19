{
  config,
  lib,
  options,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption;

  cfg = config.mountainous.zsh;
in {
  options.mountainous.zsh = {
    enable = mkEnableOption "Whether to enable zsh";
  };

  config = lib.mkIf cfg.enable {
    programs.starship = {
      enable = true;
      settings = {
        format = builtins.concatStringsSep "" [
          "$shlvl"
          "$singularity"
          "$kubernetes"
          "$vcsh"
          "$fossil_branch"
          "$fossil_metrics"
          "$git_state"
          "$git_status"
          "$pijul_channel"
          "$docker_context"
          "$package"
          "$directory"
          "$c"
          "$cmake"
          "$cobol"
          "$daml"
          "$dart"
          "$deno"
          "$dotnet"
          "$elixir"
          "$elm"
          "$erlang"
          "$fennel"
          "$gleam"
          "$golang"
          "$guix_shell"
          "$haskell"
          "$haxe"
          "$helm"
          "$java"
          "$julia"
          "$kotlin"
          "$gradle"
          "$lua"
          "$nim"
          "$nodejs"
          "$ocaml"
          "$opa"
          "$perl"
          "$php"
          "$pulumi"
          "$purescript"
          "$python"
          "$quarto"
          "$raku"
          "$rlang"
          "$red"
          "$ruby"
          "$rust"
          "$scala"
          "$solidity"
          "$swift"
          "$terraform"
          "$typst"
          "$vlang"
          "$vagrant"
          "$zig"
          "$buf"
          "$nix_shell"
          "$conda"
          "$meson"
          "$spack"
          "$memory_usage"
          "$aws"
          "$gcloud"
          "$openstack"
          "$azure"
          "$nats"
          "$env_var"
          "$crystal"
          "$custom"
          "$sudo"
          "$cmd_duration"
          "$jobs"
          "$os"
          "$container"
          "$line_break"
          "$line_break"
          "$shell"
          "$direnv"
          "$status"
          "$hostname"
          "$localip"
          "$character"
        ];

        shell = {
          format = "[$indicator]($style)";
          disabled = false;

          bash_indicator = "bsh ";
          cmd_indicator = "cmd ";
          elvish_indicator = "esh ";
          fish_indicator = "fsh ";
          ion_indicator = "ion ";
          nu_indicator = "nu ";
          powershell_indicator = "psh ";
          tcsh_indicator = "tsh ";
          xonsh_indicator = "xsh ";
          zsh_indicator = "";
        };

        status = {
          disabled = false;
          symbol = " ";
          not_executable_symbol = "󰜺 ";
          not_found_symbol = " ";
          sigint_symbol = "󱊐 ";
          signal_symbol = "󱐋 ";
          format = "[$symbol $status]($style) ";
        };

        directory = {
          truncate_to_repo = false;
          home_symbol = "󰟒 ";
          read_only = "  ";
        };

        git_status = {
          format = "[$ahead_behind$modified]($style)";
          ahead = "  ";
          behind = "  ";
          diverged = "󰦻  ";
          modified = "  ";
        };

        direnv = {
          disabled = false;
          format = "[$symbol]($style)";
          symbol = "󰏗  ";
        };

        nix_shell = {
          disabled = true;
          symbol = "󰜗 ";
        };

        hostname = {
          ssh_symbol = "󰲝  ";
          format = "[$ssh_symbol$hostname]($style) ";
        };
      };
    };

    programs.zsh = {
      enable = true;
      autocd = true;
      enableVteIntegration = true;
      enableCompletion = true;
      dotDir = ".config/zsh";

      # TODO: Set this next to nvr
      initExtra =
        # bash
        ''
          setopt EXTENDED_GLOB
          setopt AUTO_CD
          setopt INTERACTIVE_COMMENTS
          setopt CORRECT
          setopt MENU_COMPLETE
          setopt NO_NOMATCH

          watchfolder() {
            inotifywait -m -r ~/.local/share/Steam --format '%w%f' -e modify |
              grep '\.vdf$'
            }

          # Watch a file for changes and show the differences
          watchfile() {
              if [[ $# -eq 0 ]]; then
                  echo "Usage: watchfile <file>"
                  return 1
              fi

              local file="$1"
              local tmpfile="/tmp/$(${pkgs.coreutils}/bin/basename "$file")-last"

              # Create initial copy if it doesn't exist
              ${pkgs.coreutils}/bin/cp "$file" "$tmpfile" 2>/dev/null

              # Watch for changes
              echo "$file" | ${pkgs.entr}/bin/entr -n ${pkgs.bash}/bin/sh -c "${pkgs.diffutils}/bin/diff <(${pkgs.coreutils}/bin/cat '$tmpfile') '$file' 2>/dev/null | ${pkgs.gnugrep}/bin/grep -v '^[0-9]'; ${pkgs.coreutils}/bin/cp '$file' '$tmpfile'"
          }

          serve() {
            nix run nixpkgs#fd -- --type f --hidden --no-ignore | nix run nixpkgs#entr -- -r nix run nixpkgs#python3 -- -m http.server
          }

          mtn() {
            ssh \
              -tt \
              -o SendEnv=TERM \
              aka \
              "cd /snowscape/code/github/simonwjackson/mountainous/main && TERM=xterm-256color nix develop --command just $*"
          }

          # Enable responsive manpage
          export MANWIDTH=999

          if [[ -n $NVIM ]]; then
            export MANPAGER="nvr +Man! -"
          else
            export MANPAGER="nvim +Man! -"
          fi
        '';

      dirHashes = {
        docs = "${config.home.homeDirectory}/documents";
        music = "${config.home.homeDirectory}/music";
        dl = "${config.home.homeDirectory}/downloads";
        notes = "${config.home.homeDirectory}/documents/notes";
      };

      shellAliases = {
        ".." = "cd ..";
        take = "mkdir -p $1 && cd $1";
        ip = "ip --color=auto";
        run = "nix run nixpkgs#$1";
        pkg = "nix search $1";
        merge-pdfs = "gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=merged.pdf *.pdf";
        # TODO: These should be send to <device>
        website-to-pdf = "wkhtmltopdf --page-size A4 --margin-top 0 --margin-bottom 0 --margin-left 0 --margin-right 0 --print-media-type";

        all_links = "xidel --extract \"//a/resolve-uri(@href, base-uri())\" \"{$1}\" | xclip -selection clipboard";
        lan = "nmap -n -sn 192.18.1.0/24 -oG - | awk '/Up$/{print $2}' | sort -V";
      };

      history = {
        size = 0;
        save = 0;
        share = false;
        path = "/dev/null"; # Redirect history file to /dev/null
      };

      autosuggestion = {
        enable = true;
        strategy = [
          "history"
          "completion"
        ];
      };

      syntaxHighlighting = {
        enable = true;
        highlighters = [
          "main" # Highlights regular command syntax
          "brackets" # Highlights matching brackets and parentheses
          "pattern" # Highlights user-defined patterns
          "cursor" # Highlights the cursor position
          "root" # Highlights root/sudo commands
          "regexp" # Highlights regular expressions
        ];

        patterns = {
          # Previous Command Patterns
          "rm -rf *" = "fg=white,bold,bg=red";
          "rm -r *" = "fg=white,bold,bg=red";
          "sudo *" = "fg=white,bold,bg=red";
          "dd if*" = "fg=white,bold,bg=yellow";
          "> /dev/*" = "fg=white,bold,bg=red";
          "mv * /" = "fg=white,bold,bg=red";

          # System modification commands
          "chmod -R 777*" = "fg=white,bold,bg=red";
          "chmod -R 000*" = "fg=white,bold,bg=red";
          "chown -R *" = "fg=white,bold,bg=yellow";
          ":(){:|:&};:*" = "fg=white,bold,bg=red";
          "mkfs*" = "fg=white,bold,bg=red";
          "setfacl -R*" = "fg=white,bold,bg=yellow";
          "chattr +i *" = "fg=white,bold,bg=yellow";
          "chattr -i *" = "fg=white,bold,bg=red";
          "mount -o remount,rw *" = "fg=white,bold,bg=red";
          "sysctl -w *" = "fg=white,bold,bg=yellow";
          "ulimit -n unlimited" = "fg=white,bold,bg=yellow";
          "swapoff -a" = "fg=white,bold,bg=red";
          "swapon -a" = "fg=white,bold,bg=yellow";
          "modprobe -r *" = "fg=white,bold,bg=yellow";
          "modprobe --force *" = "fg=white,bold,bg=red";
          "insmod *" = "fg=white,bold,bg=red";
          "rmmod -f *" = "fg=white,bold,bg=red";
          "visudo *" = "fg=white,bold,bg=yellow";
          "echo * > /proc/sys/*" = "fg=white,bold,bg=red";
          "echo * > /sys/*" = "fg=white,bold,bg=red";
          "setenforce 0" = "fg=white,bold,bg=red";
          "apparmor_parser -R *" = "fg=white,bold,bg=red";

          # Network related
          "iptables -F*" = "fg=white,bold,bg=red";
          "tcpdump *" = "fg=white,bold,bg=yellow";
          "netcat *" = "fg=white,bold,bg=yellow";
          "nc -l *" = "fg=white,bold,bg=yellow";

          # Process management
          "kill -9 *" = "fg=white,bold,bg=yellow";
          "killall *" = "fg=white,bold,bg=yellow";
          "pkill *" = "fg=white,bold,bg=yellow";

          # Disk operations
          "fdisk *" = "fg=white,bold,bg=red";
          "parted *" = "fg=white,bold,bg=red";
          "wipefs *" = "fg=white,bold,bg=red";
          "sgdisk --zap-all *" = "fg=white,bold,bg=red";
          "gdisk *" = "fg=white,bold,bg=red";
          "cfdisk *" = "fg=white,bold,bg=red";
          "sfdisk --force *" = "fg=white,bold,bg=red";
          "hdparm --security-erase *" = "fg=white,bold,bg=red";
          "hdparm --security-set-pass *" = "fg=white,bold,bg=red";
          "blockdev --rereadpt *" = "fg=white,bold,bg=yellow";
          "blockdev --setrw *" = "fg=white,bold,bg=red";
          "dmsetup remove_all" = "fg=white,bold,bg=red";
          "lvremove -f *" = "fg=white,bold,bg=red";
          "vgremove -f *" = "fg=white,bold,bg=red";
          "pvremove -f *" = "fg=white,bold,bg=red";
          "mdadm --stop *" = "fg=white,bold,bg=red";
          "mdadm --remove *" = "fg=white,bold,bg=red";
          "mdadm --zero-superblock *" = "fg=white,bold,bg=red";
          "badblocks -w *" = "fg=white,bold,bg=red";
          "tune2fs -O ^has_journal *" = "fg=white,bold,bg=red";
          "resize2fs -f *" = "fg=white,bold,bg=red";
          "btrfs device delete *" = "fg=white,bold,bg=red";

          # Package management
          "apt-get remove *" = "fg=white,bold,bg=yellow";
          "apt-get purge *" = "fg=white,bold,bg=red";
          "pacman -Rsc *" = "fg=white,bold,bg=red";

          # Git operations
          "git reset --hard*" = "fg=white,bold,bg=yellow";
          "git clean -fd*" = "fg=white,bold,bg=yellow";
          "git rebase*" = "fg=white,bold,bg=yellow";
          "git push --force*" = "fg=white,bold,bg=red";
          "git branch -D *" = "fg=white,bold,bg=yellow";
          "git push origin :*" = "fg=white,bold,bg=red";
          "git filter-branch*" = "fg=white,bold,bg=red";
          "git update-ref -d HEAD" = "fg=white,bold,bg=red";
          "git reflog expire --expire=now --all" = "fg=white,bold,bg=red";
          "git gc --prune=now --aggressive" = "fg=white,bold,bg=red";
          "git checkout --orphan*" = "fg=white,bold,bg=yellow";
          "git submodule deinit -f *" = "fg=white,bold,bg=yellow";
          "git worktree remove -f *" = "fg=white,bold,bg=yellow";
          "git remote remove *" = "fg=white,bold,bg=yellow";
          "git push --delete*" = "fg=white,bold,bg=red";
          "git rebase --onto*" = "fg=white,bold,bg=red";
          "git cherry-pick --abort" = "fg=white,bold,bg=yellow";
          "git am --abort" = "fg=white,bold,bg=yellow";
          "git bisect reset" = "fg=white,bold,bg=yellow";
          "git rev-list --objects --all | git pack-objects --all" = "fg=white,bold,bg=red";

          # File operations
          "cp -rf /* *" = "fg=white,bold,bg=red";
          "mv /* *" = "fg=white,bold,bg=red";
          "ln -sf /* *" = "fg=white,bold,bg=yellow";

          # Archive operations
          "tar cf /* *" = "fg=white,bold,bg=yellow";
          "zip -r /* *" = "fg=white,bold,bg=yellow";

          # System control
          "shutdown *" = "fg=white,bold,bg=yellow";
          "reboot *" = "fg=white,bold,bg=yellow";
          "init *" = "fg=white,bold,bg=red";
          "systemctl stop *" = "fg=white,bold,bg=yellow";
          "systemctl mask *" = "fg=white,bold,bg=red";
          "systemctl unmask *" = "fg=white,bold,bg=yellow";
          "systemctl disable *" = "fg=white,bold,bg=yellow";
          "systemctl isolate *" = "fg=white,bold,bg=red";
          "systemctl daemon-reload" = "fg=white,bold,bg=yellow";
          "systemctl reset-failed" = "fg=white,bold,bg=yellow";
          "systemctl kill *" = "fg=white,bold,bg=red";
          "systemctl set-property *" = "fg=white,bold,bg=yellow";
          "loginctl terminate-user *" = "fg=white,bold,bg=red";
          "loginctl kill-user *" = "fg=white,bold,bg=red";
          "telinit *" = "fg=white,bold,bg=red";
          "halt -f" = "fg=white,bold,bg=red";
          "poweroff -f" = "fg=white,bold,bg=red";
          "systemctl poweroff -i" = "fg=white,bold,bg=red";
          "systemctl rescue" = "fg=white,bold,bg=red";
          "systemctl emergency" = "fg=white,bold,bg=red";
          "kernel.panic_on_oops=1" = "fg=white,bold,bg=red";

          # Database operations
          "drop database*" = "fg=white,bold,bg=red";
          "truncate table*" = "fg=white,bold,bg=red";

          # Docker operations
          "docker rm -f *" = "fg=white,bold,bg=yellow";
          "docker system prune*" = "fg=white,bold,bg=yellow";

          # User management
          "userdel *" = "fg=white,bold,bg=red";
          "groupdel *" = "fg=white,bold,bg=red";
          "passwd *" = "fg=white,bold,bg=yellow";

          # NixOS System Management
          "nixos-rebuild switch --rollback" = "fg=white,bold,bg=yellow";
          "nixos-rebuild switch --upgrade" = "fg=white,bold,bg=yellow";
          "nixos-rebuild boot*" = "fg=white,bold,bg=yellow";
          "nixos-rebuild test*" = "fg=white,bold,bg=yellow";
          "nixos-rebuild build*" = "fg=white,bold,bg=yellow";
          "nixos-generate-config*" = "fg=white,bold,bg=yellow";

          # Nix Store Operations
          "nix-store --delete*" = "fg=white,bold,bg=red";
          "nix-store --repair*" = "fg=white,bold,bg=red";
          "nix-store --verify*" = "fg=white,bold,bg=yellow";
          "nix-store --optimize*" = "fg=white,bold,bg=yellow";
          "nix-collect-garbage -d*" = "fg=white,bold,bg=red";

          # Nix Channel Management
          "nix-channel --remove*" = "fg=white,bold,bg=yellow";
          "nix-channel --update*" = "fg=white,bold,bg=yellow";
          "nix-channel --add*" = "fg=white,bold,bg=yellow";
          "nix-channel --rollback*" = "fg=white,bold,bg=yellow";

          # Nix Profile Management
          "nix-env -e *" = "fg=white,bold,bg=yellow";
          "nix-env -iA*" = "fg=white,bold,bg=yellow";
          "nix-env --rollback*" = "fg=white,bold,bg=yellow";
          "nix-env --uninstall*" = "fg=white,bold,bg=yellow";
          "nix-env --delete-generations*" = "fg=white,bold,bg=red";

          # Nix Development
          "nix develop --impure*" = "fg=white,bold,bg=yellow";
          "nix build --override-input*" = "fg=white,bold,bg=yellow";
          "nix flake update*" = "fg=white,bold,bg=yellow";

          # Nix Dangerous Operations
          "nix-shell --pure*" = "fg=white,bold,bg=yellow";
          "nix copy --no-check-sigs*" = "fg=white,bold,bg=red";
          "nix-copy-closure --gzip*" = "fg=white,bold,bg=yellow";

          # NixOS Hardware Management
          "nixos-generate-config --force*" = "fg=white,bold,bg=red";
          "nixos-install --no-root-passwd*" = "fg=white,bold,bg=red";
          "nixos-enter*" = "fg=white,bold,bg=yellow";

          # Nix Cache Operations
          "nix-push*" = "fg=white,bold,bg=yellow";
          "nix copy --to*" = "fg=white,bold,bg=yellow";
          "nix copy --from*" = "fg=white,bold,bg=yellow";
          "nix-copy-closure*" = "fg=white,bold,bg=yellow";

          # Nix Build Operations
          "nix build --no-link*" = "fg=white,bold,bg=yellow";
          "nix build --check*" = "fg=white,bold,bg=yellow";
          "nix build --repair*" = "fg=white,bold,bg=red";

          # Flakes Operations
          "nix flake lock --update-input*" = "fg=white,bold,bg=yellow";
          "nix flake new*" = "fg=white,bold,bg=yellow";
          "nix flake clone*" = "fg=white,bold,bg=yellow";
          "nix flake archive*" = "fg=white,bold,bg=yellow";

          # Configuration Management
          "sudo mv * /etc/nixos/*" = "fg=white,bold,bg=red";
          "sudo rm /etc/nixos/*" = "fg=white,bold,bg=red";
          "sudo nixos-rebuild switch --option binary-caches*" = "fg=white,bold,bg=red";

          # Experimental Features
          "nix --experimental-features*" = "fg=white,bold,bg=yellow";
          "nixos-rebuild --option sandbox*" = "fg=white,bold,bg=yellow";
          "nix-daemon --option allow-unsafe-native-code-during-evaluation*" = "fg=white,bold,bg=red";
        };

        styles = {
          # Basic syntax elements
          "alias" = "fg=magenta,bold";
          "builtin" = "fg=green,bold";
          "command" = "fg=green";
          "function" = "fg=blue,bold";
          "precommand" = "fg=cyan,underline";
          "comment" = "fg=black,bold";
          "path" = "fg=cyan";

          # Quoted arguments
          "single-quoted-argument" = "fg=yellow";
          "double-quoted-argument" = "fg=yellow";
          "dollar-quoted-argument" = "fg=yellow";
          "back-quoted-argument" = "fg=yellow";

          # Special syntax
          "assign" = "fg=magenta";
          "redirection" = "fg=brightblue";
          "arg0" = "fg=cyan";
          "default" = "fg=default";
          "unknown-token" = "fg=red,bold";
          "reserved-word" = "fg=yellow,bold";
          "globbing" = "fg=blue";
          "history-expansion" = "fg=blue";

          # Command options
          "single-hyphen-option" = "fg=cyan";
          "double-hyphen-option" = "fg=cyan";

          # Unclosed quotes and syntax errors
          "back-quoted-argument-unclosed" = "fg=red,bold";
          "single-quoted-argument-unclosed" = "fg=red,bold";
          "double-quoted-argument-unclosed" = "fg=red,bold";
          "dollar-quoted-argument-unclosed" = "fg=red,bold";
        };
      };
    };
  };
}
