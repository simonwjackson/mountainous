{
  mountainous.presets.core.enable = true;

  mountainous.features.atuin.enable = true;
  mountainous.features.starship = {
    enable = true;
    hostName = "usu";
  };

  mountainous.features.sshd = {
    enable = true;
    authorizedKeysUrl = "https://github.com/simonwjackson.keys";
  };

  mountainous.features.mosh.enable = true;

  mountainous.features.secrets = {
    enable = true;
    identityFile = "/data/data/com.termux.nix/files/home/.ssh/id_rsa";
    secretsDir = "/data/data/com.termux.nix/files/home/.secrets";
    secrets = {
      atuin-key.file = ../../secrets/user/simonwjackson/atuin/key.age;
      atuin-session.file = ../../secrets/user/simonwjackson/atuin/session.age;
    };
  };
}
