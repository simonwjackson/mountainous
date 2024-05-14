{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) concatMapStrings concatStringsSep mapAttrsToList isAttrs mkEnableOption mkOption recursiveUpdate mkIf;
  inherit (lib.types) str attrs attrsOf;

  cfg = config.mountainous.tridactyl;

  # Define a function to handle the conversion of the 'unbind' list.
  handleUnbind = value:
    if builtins.isList value && builtins.all builtins.isString value
    then concatMapStrings (elem: "unbind " + toString elem + "\n") value
    else throw "value must be a list of strings";

  # Updated toTridactylrcLines to handle special cases and general settings
  toTridactylrcLines = prefix: config:
    concatStringsSep "\n" (mapAttrsToList (
        name: value:
          if name == "unbind" && prefix == []
          then handleUnbind value
          else if isAttrs value
          then toTridactylrcLines (prefix ++ [name]) value
          else "${concatStringsSep " " prefix} ${name} ${toString value}"
      )
      config);

  # Function to generate the tridactylrc content
  generateTridactylrc = cfg: let
    unbind = handleUnbind cfg.settings.unbind;
    restSettings = removeAttrs cfg.settings ["unbind"];
  in ''
    " vim: set filetype=tridactyl
    " Idempotent config
    sanitise tridactyllocal tridactylsync
    ${unbind}
    ${toTridactylrcLines [] restSettings}
    ${cfg.extraSettings}
  '';

  # Custom error for attribute name clashes
  attributeNameClashError = name: path:
    throw "Attribute name clash detected for '${name}' at path '${lib.concatStringsSep "." path}'";

  # Recursive update with clash detection
  recursiveUpdateWithClashDetection = path: a: b: let
    allNames = lib.unique (lib.attrNames a ++ lib.attrNames b);
  in
    lib.foldl' (
      acc: name: let
        aVal =
          if lib.hasAttr name a
          then a.${name}
          else {};
        bVal =
          if lib.hasAttr name b
          then b.${name}
          else {};
      in
        if lib.isAttrs aVal && lib.isAttrs bVal
        then acc // {${name} = recursiveUpdateWithClashDetection (path ++ [name]) aVal bVal;}
        else if aVal != {} && bVal != {}
        then attributeNameClashError name path
        else
          acc
          // (
            if bVal != {}
            then {${name} = bVal;}
            else {${name} = aVal;}
          )
    ) {}
    allNames;

  # Merge the contents of the named modules while checking for clashes
  mergeModules = modules:
    lib.foldl' (
      acc: name:
        recursiveUpdateWithClashDetection [name] acc (modules.${name})
    ) {} (lib.attrNames modules);
in {
  options.mountainous.tridactyl = {
    enable = mkEnableOption "Tridactyl browser extension";

    settings = mkOption {
      default = {};
      type = attrs;
      description = "Miscellaneous settings for Tridactyl.";
    };

    modules = mkOption {
      default = {};
      type = attrsOf attrs;
      description = "Tridactyl modules configuration.";
    };

    extraSettings = mkOption {
      default = "";
      type = str;
      description = "Additional plain string settings to be appended at the end of the tridactylrc file.";
    };
  };

  config = mkIf cfg.enable {
    # home.packages = with pkgs; [
    #   tridactyl-native
    # ];

    # Combine settings with the modules
    home.file.".config/tridactyl/tridactylrc".text = let
      combinedSettings = recursiveUpdate cfg.settings (mergeModules cfg.modules);
    in
      generateTridactylrc {
        settings = combinedSettings;
        extraSettings = cfg.extraSettings;
      };
  };
}
