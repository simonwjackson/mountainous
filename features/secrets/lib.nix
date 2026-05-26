# Pure functions for convention-based secrets auto-discovery.
#
# Directory conventions:
#   secrets/<name>.age                       → global, root:root 0400
#   secrets/hosts/<hostname>/<name>.age      → host-scoped, root:root 0400
#   secrets/user/<username>/<sub>/<name>.age → all hosts, <username>:users 0400
#   secrets/system/<sub>/<name>.age          → all hosts, root:root 0400
#
# Filename metadata (optional, underscore-separated key=value tags):
#   <name>_o=<owner>_g=<group>_m=<mode>.age
#
# Tags are identified by containing '='.  Non-tag segments form the name.
# Skipped directories: archived, keys
{lib}: let
  inherit
    (lib)
    concatMap
    concatStringsSep
    drop
    filter
    hasSuffix
    hasPrefix
    removeSuffix
    splitString
    ;

  # Parse "nzbget-pass_o=nzbget_g=media_m=0440.age"
  # → { name = "nzbget-pass"; owner = "nzbget"; group = "media"; mode = "0440"; }
  #
  # Splits on '_', segments containing '=' are metadata tags, the rest
  # are rejoined with '_' to form the secret name.
  parseFilename = filename: let
    withoutAge = removeSuffix ".age" filename;
    segments = splitString "_" withoutAge;
    isTag = s: builtins.match ".*=.*" s != null;
    nameParts = filter (s: !(isTag s)) segments;
    tagParts = filter isTag segments;
    name = concatStringsSep "_" nameParts;
    parseTag = tag: let
      kv = splitString "=" tag;
    in {
      key = builtins.head kv;
      value =
        if builtins.length kv > 1
        then builtins.elemAt kv 1
        else "";
    };
    tagAttrs = builtins.listToAttrs (
      map (t: let
        p = parseTag t;
      in {
        name = p.key;
        value = p.value;
      })
      tagParts
    );
  in {
    inherit name;
    owner = tagAttrs.o or null;
    group = tagAttrs.g or null;
    mode = tagAttrs.m or null;
  };

  # Recursively scan a directory for .age files.
  # Returns list of { filename, file, relDir }
  scanDir = dir: relDir: let
    entries =
      if builtins.pathExists dir
      then builtins.readDir dir
      else {};
    process = entryName: let
      type = entries.${entryName};
      fullPath = dir + "/${entryName}";
      newRelDir =
        if relDir == ""
        then entryName
        else "${relDir}/${entryName}";
    in
      if type == "directory" && entryName != "archived" && entryName != "keys"
      then scanDir fullPath newRelDir
      else if type == "regular" && hasSuffix ".age" entryName
      then [
        {
          filename = entryName;
          file = fullPath;
          inherit relDir;
        }
      ]
      else [];
  in
    concatMap process (builtins.attrNames entries);

  # Derive the secret attr name from its relative directory and parsed filename.
  deriveSecretName = relDir: parsed:
    if hasPrefix "hosts/" relDir
    then
      # hosts/<hostname>/<name>.age → <name>
      parsed.name
    else if hasPrefix "user/" relDir
    then let
      # user/<username>/<sub>/.../<name>.age → <sub>-...-<name>
      parts = splitString "/" relDir;
      intermediateParts = drop 2 parts;
      prefix = concatStringsSep "-" intermediateParts;
    in
      if prefix == ""
      then parsed.name
      else "${prefix}-${parsed.name}"
    else if hasPrefix "system/" relDir
    then
      # system/<sub>/<name>.age → <name>
      parsed.name
    else
      # Root level → <name>
      parsed.name;

  # Derive default ownership from directory location + filename metadata.
  deriveOwnership = relDir: parsed:
    if hasPrefix "user/" relDir
    then let
      parts = splitString "/" relDir;
      userName = builtins.elemAt parts 1;
    in {
      owner =
        if parsed.owner != null
        then parsed.owner
        else userName;
      group =
        if parsed.group != null
        then parsed.group
        else "users";
      mode =
        if parsed.mode != null
        then parsed.mode
        else "0400";
    }
    else {
      owner =
        if parsed.owner != null
        then parsed.owner
        else "root";
      group =
        if parsed.group != null
        then parsed.group
        else "root";
      mode =
        if parsed.mode != null
        then parsed.mode
        else "0400";
    };

  # Main discovery entry point.
  #
  #   secretsRoot : path   – the secrets/ directory
  #   hostname    : string | null – current host (null = skip host-scoped secrets)
  #
  # Returns: { "<secret-name>" = { file, owner, group, mode }; }
  discover = {
    secretsRoot,
    hostname ? null,
  }: let
    allFiles = scanDir secretsRoot "";

    processFile = f: let
      parsed = parseFilename f.filename;
      secretName = deriveSecretName f.relDir parsed;
      ownership = deriveOwnership f.relDir parsed;
      scope =
        if hasPrefix "hosts/" f.relDir
        then "host"
        else if hasPrefix "user/" f.relDir
        then "user"
        else if hasPrefix "system/" f.relDir
        then "system"
        else "global";
    in
      if scope == "host"
      then let
        parts = splitString "/" f.relDir;
        hostDir = builtins.elemAt parts 1;
      in
        if hostname != null && hostDir == hostname
        then {
          name = secretName;
          value = {
            inherit (ownership) owner group mode;
            inherit scope;
            file = f.file;
          };
        }
        else null
      else {
        name = secretName;
        value = {
          inherit (ownership) owner group mode;
          inherit scope;
          file = f.file;
        };
      };

    processed = filter (x: x != null) (map processFile allFiles);

    # Global/root entries take priority over system entries (same name).
    # Host entries take priority over everything.
    scopePriority = scope:
      {
        global = 0;
        user = 1;
        system = 2;
      }
      .${
        scope
      }
      or 99;

    hostEntries = filter (e: e.value.scope == "host") processed;
    otherEntries = filter (e: e.value.scope != "host") processed;

    sortedOther = lib.sort (a: b:
      scopePriority a.value.scope < scopePriority b.value.scope)
    otherEntries;

    # listToAttrs keeps the first occurrence → global beats system on collision.
    baseAttrs = builtins.listToAttrs sortedOther;
    hostAttrs = builtins.listToAttrs hostEntries;

    # Strip the internal "scope" field from the final output.
    combined = baseAttrs // hostAttrs;
  in
    builtins.mapAttrs (_: v: builtins.removeAttrs v ["scope"]) combined;
in {
  inherit parseFilename discover;
}
