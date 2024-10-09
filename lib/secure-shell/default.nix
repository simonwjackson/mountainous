{
  lib,
  inputs,
}: let
  inherit (lib.snowfall.fs) get-file;
in rec {
  knownHostsBuilder = {
    domains,
    localhost,
    systemsDir,
  }: let
    architectures = builtins.attrNames (builtins.readDir systemsDir);
    getHosts = arch: builtins.attrNames (builtins.readDir "${systemsDir}/${arch}");

    readPublicKey = arch: name: let
      keyPath = "${systemsDir}/${arch}/${name}/ssh_host_rsa_key.pub";
    in
      if builtins.pathExists keyPath
      then builtins.readFile keyPath
      else null;

    generateExtraHostNames = name:
      (
        if name == localhost
        then ["localhost,::1,127.0.0.1"]
        else []
      )
      ++ map (domain: "${name}.${domain}") domains;

    hostConfigs =
      builtins.concatMap
      (
        arch:
          map
          (name: {
            inherit name;
            value = {
              publicKey = readPublicKey arch name;
              extraHostNames = generateExtraHostNames name;
            };
          })
          (getHosts arch)
      )
      architectures;

    filteredHostConfigs =
      builtins.filter (config: config.value.publicKey != null) hostConfigs;
  in
    builtins.listToAttrs filteredHostConfigs;
}
