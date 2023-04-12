{ config, pkgs, lib, ... }:

{
  imports = [
    ./desktop
    ./terminal
    ../../modules/neovim
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

  home.sessionVariables = {
    FZF_DEFAULT_OPTS = "--reverse --layout=reverse --color=bg+:-1 --ansi --marker='❖' --pointer='❯' --prompt='  '";
    MPV_SOCKET = "/run/user/\$(id -u)/mpv.socket";
    OPENAI_API_KEY = builtins.getEnv ("OPENAI_API_KEY");
    GDK_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
    GDK_DPI_SCALE = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 0.5 else 1;
    QT_AUTO_SCREEN_SET_FACTOR = 1;
    QT_QPA_PLATFORMTHEME = "qt5ct";
    QT_SCALE_FACTOR = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then 2 else 1;
    QT_FONT_DPI = 96;
  };

  programs.mpvd.enable = true;
  programs.media-control.enable = true;
  programs.fuzzy-music.enable = true;

  # TODO: Find a way to enable this dynamicaly by system type

  xresources = {
    properties = {
      "Xcursor.size" = 46;
      "Xft.autohint" = 0;
      "Xft.lcdfilter" = "lcddefault";
      "Xft.hintstyle" = "hintfull";
      "Xft.hinting" = 1;
      "Xft.antialias" = 1;
      "Xft.rgba" = "r=b";
      "Xft.dpi" = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then "144" else "96";
      "*.dpi" = if (builtins.getEnv ("NIX_CONFIG_HIDPI") == "1") then "144" else "96";
    };
  };

  home = {
    username = "simonwjackson";
    homeDirectory = "/home/simonwjackson";

    shellAliases = {
      merge-pdfs = "gs -dBATCH -dNOPAUSE -q -sDEVICE=pdfwrite -sOutputFile=merged.pdf *.pdf";
      website-to-pdf = "wkhtmltopdf --page-size A4 --margin-top 0 --margin-bottom 0 --margin-left 0 --margin-right 0 --print-media-type";
      try = "nix-shell -p";
      run = "nix-shell -p $1 --run $1";
      cat = "bat --style=plain";
      sl = "exa";
      ls = "exa";
      l = "exa -l";
      la = "exa -la";
      ip = "ip --color=auto";
    };

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

  services.udiskie = {
    enable = true;
  };

  systemd.user = {
    services.xsettingsd = {
      Unit = {
        Description = "xsettingsd";
      };
      Service = {
        Type = "simple";
        ExecStart = "${pkgs.xsettingsd}/bin/xsettingsd";
        ExecStop = "pkill xsettingsd";
      };
      Install = {
        WantedBy = [ "multi-user.target" ];
      };
    };

    services.xsettingsd-watcher = {
      Unit = {
        Description = "xsettingsd restarter";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.systemd}/bin/systemctl --user restart xsettingsd.service";
      };
      Install = {
        WantedBy = [ "multi-user.target" ];
      };
    };

    paths.xsettingsd-watcher = {
      Path = {
        PathModified = "/home/simonwjackson/.xsettingsd";
      };
      Install = {
        WantedBy = [ "multi-user.target" ];
      };
    };
  };

  # TODO: Place this next to syncthing config
  home.file = {
    ".npmrc" = {
      source = ./npmrc;
    };
    "./code/.stignore" = {
      text = ''
        **/node_modules
        **/dist
      '';
    };
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  programs.beets = {
    enable = true;
    settings = {
      match = {
        strong_rec_thresh = 0.20;
      };
      clutter = [ "*" ];
      plugins = lib.strings.concatStringsSep " " [
        "bpd"
        "export"
        "duplicates"
        "missing"
      ];
      import = {
        duplicate_action = "merge";
      };
      duplicates = {
        tiebreak = {
          items = [ "bitrate" ];
        };
      };
      paths = {
        default = "$album - $albumartist [$year]/$track - $title";
        singleton = "Non-Album/$artist - $title";
        comp = "Compilations/$album%aunique{} [$year]/$track - $title";
      };
      directory = "/run/media/simonwjackson/microsd/Music";
      library = "~/.local/share/musiclibrary.db";
    };
  };

  programs.aria2 = {
    enable = true;
    settings = {
      dht-listen-port = 60000;
      dir = "~/downloads";
      enable-rpc = true;
      ftp-pasv = true;
      listen-port = 60000;
      max-concurrent-downloads = 5;
      max-connection-per-server = 1;
      max-upload-limit = "50K";
      rpc-listen-port = 6800;
      rpc-secret = builtins.getEnv "ARIA2_RPC_SECRET";
      on-download-complete = "notify-send 'Download complete' 'Download of %s completed'";
      on-download-error = "notify-send 'Download error' 'Download of %s failed'";
      on-download-pause = "notify-send 'Download paused' 'Download of %s paused'";
      on-download-start = "notify-send 'Download started' 'Download of %s started'";
      on-bt-download-complete = "notify-send 'Download complete' 'Download of %s completed'";
      on-bt-download-error = "notify-send 'Download error' 'Download of %s failed'";
      on-bt-download-pause = "notify-send 'Download paused' 'Download of %s paused'";
      on-bt-download-start = "notify-send 'Download started' 'Download of %s started'";
      # BitTorrent
      seed-ratio = 0.0000001;
    };
  };

  systemd.user.services.aria2 = {
    Unit = {
      Description = "aria2 background service";
    };
    Service = {
      ExecStart = "${pkgs.aria2}/bin/aria2c";
      Restart = "always";
    };
    Install = {
      WantedBy = [ "network-online.target" "default.target" ];
    };
  };

  programs.taskwarrior = {
    enable = true;
  };
}
