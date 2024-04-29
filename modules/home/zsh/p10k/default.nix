{config, ...}: {
  programs.zsh.envExtra = ''

  '';

  programs.zsh.initExtra = ''
    function prompt_in_nix_shell () {
      [[ -z "$IN_NIX_SHELL" ]] || p10k segment -b blue -f '#ffffff' -t 'nix';
    }
  '';

  programs.zsh.localVariables = {
    POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD = true;
    # POWERLEVEL9K_CONFIG_FILE = "${config.home.homeDirectory}/.config/zsh/p10k.zsh";
    # POWERLEVEL9K_LEFT_PROMPT_ELEMENTS = [
    #   "context"                   # user@host
    #   "dir"                       # current directory
    #   "vcs"                       # git status
    #   "command_execution_time"    # previous command duration
    #   # =========================[ Line #2 ]=========================
    #   "newline"                   # \n
    #   "virtualenv"                # python virtual environment
    #   "prompt_char"               # prompt symbol
    # ];
  };

  home.file = {
    "./.config/zsh/p10k.zsh" = {
      source = ./p10k.zsh;
    };
  };
}
