{
  lib,
  mountainousPlatform ? "nixos",
  ...
}: let
  inherit (lib) mkEnableOption mkOption optional types;
in {
  imports = optional (mountainousPlatform == "nixos") ./nixos.nix;

  options.mountainous.features.shell-secrets = {
    enable = mkEnableOption "Expose decrypted agenix secrets as env vars in the user's interactive shell";

    user = mkOption {
      type = types.str;
      default = "simonwjackson";
      description = "Home-manager user that receives the env-var wiring.";
    };

    vars = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = {
        BRAVE_API_KEY = "brave-api-key";
        OPENAI_API_KEY = "openai-api-key";
      };
      description = ''
        Map of environment-variable name to agenix secret attribute name
        (i.e. the key under `config.age.secrets`, derived from the .age
        filename by the secrets discovery convention).

        Each referenced secret must be declared. A missing reference fails
        the build with an actionable assertion message.

        At runtime, variables are exported only when the decrypted file is
        readable; an unreadable file is skipped silently so first-boot and
        partial-rekey hosts still get a working shell.
      '';
    };
  };
}
