{
  mountainous.presets.core.enable = true;

  mountainous.features.atuin.enable = true;
  mountainous.features.starship = {
    enable = true;
    hostName = "usu";
  };

  mountainous.features.ssh.server = {
    enable = true;
    port = 2345;
    mosh.enable = true;
  };

  mountainous.features.secrets = {
    enable = true;
    hostname = "usu";
    identityFile = "/data/data/com.termux.nix/files/home/.ssh/id_rsa";
    secretsDir = "/data/data/com.termux.nix/files/home/.secrets";
  };
}
