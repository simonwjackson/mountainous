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
