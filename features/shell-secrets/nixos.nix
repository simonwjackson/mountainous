{
  config,
  lib,
  ...
}: let
  inherit (lib) concatMapStringsSep escapeShellArg mapAttrsToList mkIf;
  cfg = config.mountainous.features.shell-secrets;

  resolved =
    mapAttrsToList (envName: secretName: {
      inherit envName secretName;
      path = config.age.secrets.${secretName}.path or null;
    })
    cfg.vars;

  # Snippet runs in interactive shell init (.bashrc / .zshrc). Each var is
  # exported independently so one missing/unreadable secret can't block the
  # others. Trailing newlines in the decrypted file are stripped by
  # `$(cat ...)`. POSIX-compatible so the same text works for bash and zsh;
  # extend the program-injection block below for other shells as needed.
  initSnippet =
    concatMapStringsSep "\n" (e: ''
      if [ -r ${escapeShellArg e.path} ]; then
        export ${e.envName}="$(cat ${escapeShellArg e.path})"
      fi
    '')
    resolved;

  hasVars = resolved != [];
in {
  config = mkIf cfg.enable {
    assertions =
      mapAttrsToList (envName: secretName: {
        assertion = config.age.secrets ? ${secretName};
        message = ''
          mountainous.features.shell-secrets.vars.${envName} references
          agenix secret "${secretName}", which is not declared.

          Either add a matching .age file under secrets/ (the discovery
          convention will register it) or remove this entry.
        '';
      })
      cfg.vars;

    # Setting initContent/initExtra is harmless when a given shell is not
    # enabled in home-manager: HM only renders that shell's rc file when
    # programs.<shell>.enable = true. So we wire every supported shell
    # unconditionally and let HM gate the actual write.
    home-manager.users.${cfg.user} = mkIf hasVars {
      programs.bash.initExtra = initSnippet;
      programs.zsh.initContent = initSnippet;
    };
  };
}
