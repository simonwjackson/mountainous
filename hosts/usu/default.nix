{
  mountainous = {
    presets.core.enable = true;

    features = {
      # ── Networking ───────────────────────────────────────────────────
      secrets = {
        enable = true;
        hostname = "usu";
        identityFile = "/data/data/com.termux.nix/files/home/.ssh/id_rsa";
        secretsDir = "/data/data/com.termux.nix/files/home/.secrets";
      };
      ssh.server = {
        enable = true;
        port = 2345;
        mosh.enable = true;
      };

      # ── User tools ──────────────────────────────────────────────────
      atuin.enable = true;
      starship = {
        enable = true;
        hostName = "usu";
      };
    };
  };
}
