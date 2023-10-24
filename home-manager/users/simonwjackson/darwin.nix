{ age, config, ... }: {
  age.secretsDir = config.home.homeDirectory + "/.local/share/keys";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}
