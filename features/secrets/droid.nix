{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.mountainous.features.secrets;

  decryptScript = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: secret: ''
      $VERBOSE_ECHO "Decrypting secret: ${name} -> ${secret.path}"
      mkdir -p "$(dirname '${secret.path}')"
      rm -f '${secret.path}'
      ${pkgs.age}/bin/age -d -i '${cfg.identityFile}' -o '${secret.path}' '${secret.file}'
      chmod ${secret.mode} '${secret.path}'
    '')
    cfg.secrets);
in {
  config = lib.mkIf (cfg.enable && cfg.secrets != {}) {
    environment.packages = [pkgs.age];

    build.activationAfter.decryptSecrets = ''
      if [[ ! -f '${cfg.identityFile}' ]]; then
        errorEcho "Secrets identity file not found: ${cfg.identityFile}"
        errorEcho "Generate one with: ssh-keygen -t ed25519 -f ${cfg.identityFile} -N \"\""
      else
        mkdir -p '${cfg.secretsDir}'
        chmod 700 '${cfg.secretsDir}'
        ${decryptScript}
      fi
    '';
  };
}
