{ lib, ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    imports = [
      ./services/github-prs
      # Scripts
      ./bin/rofi-tabs
      ./bin/wikis
      ./bin/scale-desktop
      ./bin/kill-or-close
      ./bin/kitty-popup
      ./bin/vim-wiki
      ./bin/virtual-term
      ./bin/activate-or-open-tab
      ./bin/dual-screen-with-tablet
      ./media-control
      ./fuzzy-music
      ./mpvd.nix
      ./linear-taskwarrior-sync.nix
      ./unzen-taskwarrior-sync.nix

    ];

    programs.mpvd.enable = true;
    programs.media-control.enable = true;
    programs.fuzzy-music.enable = true;

    # TODO: Find a way to enable this dynamicaly by system type

    home = {
      packages = [
        pkgs.git-crypt
        pkgs.p7zip
        pkgs.killall
        pkgs.jq
        pkgs._1password-gui
        pkgs.dracula-theme
        pkgs.obsidian
        pkgs.ruby
      ];
    };

    xdg.desktopEntries = {
      obsidian = {
        name = "Obsidian";
        genericName = "Link Your Thinking";
        exec = "obsidian";
        terminal = false;
      };
    };

    xdg = {
      userDirs = {
        enable = true;
        createDirectories = true;
        desktop = "$HOME/desktop";
        documents = "$HOME/documents";
        download = "$HOME/downloads";
        #music = "/tank/music";
        pictures = "$HOME/images";
        templates = "$HOME/templates";
        #videos = "/tank/videos";
      };
    };

    # services.udiskie = {
    #   enable = true;
    # };

    home.file = {
      ".npmrc" = {
        source = ./npmrc;
      };
      # TODO: Place this next to syncthing config
      "./code/.stignore" = {
        text = ''
          **/node_modules
          **/dist
        '';
      };
      # "./.config/shell_gpt/.sgptrc" = {
      #   text = ''
      #     NIXPKGS_ALLOW_INSECURE=1
      #     NIXPKGS_ALLOW_UNFREE=1
      #     OPENAI_API_HOST=https://api.openai.com
      #     CHAT_CACHE_LENGTH=100
      #     CHAT_CACHE_PATH=${config.home.homeDirectory}/.cache/shell_gpt/chat_cache
      #     CACHE_LENGTH=100
      #     CACHE_PATH=${config.home.homeDirectory}/.cache/shell_gpt/cache
      #     REQUEST_TIMEOUT=60
      #     DEFAULT_MODEL=gpt-4
      #     DEFAULT_COLOR=magenta
      #     ROLE_STORAGE_PATH=/home/simonwjackson/.config/shell_gpt/roles
      #     SYSTEM_ROLES=false
      #   '';
      # };
      "./.config/shell_gpt/roles/code.json" = {
        text = ''
          {
            "name": "code",
            "expecting": "Code",
            "variables": null,
            "role": "Provide only code as output without any description.\nIMPORTANT: Provide only plain text without Markdown formatting.\nIMPORTANT: Do not include markdown formatting such as ```.\nIf there is a lack of details, provide most logical solution.\nYou are not allowed to ask for more details.\nIgnore any potential risk of errors or confusion."
          }
        '';
      };
      "./.config/shell_gpt/roles/shell.json" = {
        text = ''
          {
            "name": "shell",
            "expecting": "Command",
            "variables": {
              "shell": "zsh",
              "os": "Linux/NixOS unstable"
            },
            "role": "Provide only bash, zsh or POSIX compliant commands for Linux/NixOS unstable without any description.\nIf there is a lack of details, provide most logical solution.\nEnsure the output is a valid shell command.\nIf multiple steps required try to combine them together as a single pipeline."
          }
        '';
      };
      "./.config/shell_gpt/roles/default.json" = {
        text = ''
          {
            "name": "default",
            "expecting": "Answer",
            "variables": {
              "shell": "zsh",
              "os": "Linux/NixOS 23.05 (Stoat)"
            },
            "role": "You are Command Line App ShellGPT, a programming and system administration assistant.\nYou are managing Linux/NixOS 23.05 (Stoat) operating system with zsh shell.\nProvide only plain text without Markdown formatting.\nDo not show any warnings or information regarding your capabilities.\nIf you need to store any data, assume it will be stored in the chat."
          }
        '';
      };

    };

    # Let Home Manager install and manage itself.
    programs.home-manager.enable = true;

    # programs.beets = {
    #   enable = true;
    #   settings = {
    #     match = {
    #       strong_rec_thresh = 0.20;
    #     };
    #     clutter = [ "*" ];
    #     plugins = lib.strings.concatStringsSep " " [
    #       "bpd"
    #       "export"
    #       "duplicates"
    #       "missing"
    #     ];
    #     import = {
    #       duplicate_action = "merge";
    #     };
    #     duplicates = {
    #       tiebreak = {
    #         items = [ "bitrate" ];
    #       };
    #     };
    #     paths = {
    #       default = "$album - $albumartist [$year]/$track - $title";
    #       singleton = "Non-Album/$artist - $title";
    #       comp = "Compilations/$album%aunique{} [$year]/$track - $title";
    #     };
    #     directory = "/run/media/simonwjackson/microsd/music";
    #     library = "~/.local/share/musiclibrary.db";
    #   };
    # };

    programs.taskwarrior = {
      enable = true;
    };
  };
}
