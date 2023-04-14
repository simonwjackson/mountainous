{ ... }:

let
  home-manager = builtins.fetchTarball "https://github.com/nix-community/home-manager/archive/master.tar.gz";
in
{
  imports = [
    (import "${home-manager}/nixos")
  ];

  programs.zsh.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  sound.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  home-manager.users.simonwjackson = { config, pkgs, ... }: {
    imports = [ ];

    home.shellAliases = {
      someday = "task add proj:someday";

      unzen = "mosh unzen -- sh -c 'tmux attach || tmux new-session'";
      ushiro = "mosh ushiro -- sh -c 'tmux attach || tmux new-session'";

      h = "fzf-history-widget";
      more = "less";
      ll = "exa --long --header --git ";
      top = "btop";
      lan = "nmap -n -sn 192.18.1.0/24 -oG - | awk '/Up$/{print $2}' | sort -V";
      wgn = "nmap -n -sn 192.18.2.0/24 -oG - | awk '/Up$/{print $2}' | sort -V";
      all_links = "xidel --extract \"//a/resolve-uri(@href, base-uri())\" \"{$1}\" | xclip -selection clipboard";
      kvm = "nix-shell -p barrier --run '{ ssh -N -R 24800:localhost:24800 ushiro.lan; } & { barriers -f --no-tray --debug INFO --name fiji --disable-client-cert-checking --disable-crypto -c ~/ushiro.barriers.conf --address :24800; } & wait -n; pkill -P $$;'";
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

    home.file = {
      "./.config/zsh/.p10k.zsh" = {
        source = ./rc/p10k.zsh;
      };
    };

    programs.zsh = {
      enable = true;
      autocd = true;
      dotDir = ".config/zsh";
      enableSyntaxHighlighting = true;
      enableAutosuggestions = true;
      enableCompletion = true;

      initExtraBeforeCompInit = ''
        POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

        source ~/.config/zsh/.p10k.zsh
      '';

      plugins = with pkgs; [
        {
          file = "powerlevel10k.zsh-theme";
          name = "powerlevel10k";
          src = "${zsh-powerlevel10k}/share/zsh-powerlevel10k";
        }
      ];

      dirHashes = {
        docs = "$HOME/Documents";
        dl = "$HOME/Downloads";
      };

      # oh-my-zsh = {
      #   enable = true;
      #   plugins = [ "git" "vi-mode" ];
      #   theme = "robbyrussell";
      # };

      initExtra =
        builtins.readFile (./rc/base.zsh) +
        builtins.readFile (./rc/bindings.zsh);

      history = {
        save = 999999999;
        size = 999999999;
      };
    };
  };
}
