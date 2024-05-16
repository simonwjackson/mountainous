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
  imports = [
    ./p10k
  ];

  options.mountainous.zsh = {
    enable = mkEnableOption "Whether to enable zsh";
  };

  config = lib.mkIf cfg.enable {
    programs.zsh = {
      enable = true;
      autocd = true;
      enableVteIntegration = true;
      enableCompletion = true;
      # dotDir = ".config/zsh";

      # TODO: Set this next to nvr
      initExtra = ''
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
        expireDuplicatesFirst = true;
        ignoreAllDups = true;
        extended = true;
        size = 999999;
        save = 999999;
        share = true;
        path = "${config.xdg.dataHome}/zsh/history";
        ignorePatterns = ["rm *" "pkill *"];
      };

      zplug = {
        enable = true;
        plugins = [
          {name = "zsh-users/zsh-syntax-highlighting";}
          {name = "zsh-users/zsh-autosuggestions";} # Simple plugin installation
          # { name = "romkatv/powerlevel10k"; tags = [ as:theme depth:1 ]; } # Installations with additional options. For the list of options, please refer to Zplug README.
        ];
      };
    };
  };
}
