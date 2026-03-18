{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkIf mapAttrsToList concatStringsSep;
  cfg = config.mountainous.features.secrets;
  secretsLib = import ./lib.nix {inherit lib;};

  discovered = secretsLib.discover {
    secretsRoot = ../../secrets;
    hostname = cfg.hostname;
  };

  # Merge auto-discovered secrets with any manually declared extras.
  # Manual entries override auto-discovered ones with the same name.
  autoEntries = builtins.mapAttrs (_: s: {
    inherit (s) file mode;
  }) discovered;

  manualEntries = builtins.mapAttrs (_: s: {
    inherit (s) file mode;
  }) cfg.secrets;

  allSecrets = autoEntries // manualEntries;

  decryptScript = concatStringsSep "\n" (mapAttrsToList (name: secret: ''
    $VERBOSE_ECHO "Decrypting secret: ${name} -> ${cfg.secretsDir}/${name}"
    mkdir -p "${cfg.secretsDir}"
    rm -f '${cfg.secretsDir}/${name}'
    ${pkgs.age}/bin/age -d -i '${cfg.identityFile}' -o '${cfg.secretsDir}/${name}' '${secret.file}'
    chmod ${secret.mode} '${cfg.secretsDir}/${name}'
  '') allSecrets);
in {
  config = mkIf (cfg.enable && allSecrets != {}) {
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

    # Unified path accessor
    mountainous.features.secrets.path =
      builtins.mapAttrs (name: _: "${cfg.secretsDir}/${name}") allSecrets;
  };
}
