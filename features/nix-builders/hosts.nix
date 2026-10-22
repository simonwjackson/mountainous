# The fleet's build federation registry, read from fleet.json.
#
# cairn owns the registry (modules/build-federation.nix and each host file).
# fleet.json is its copy for the hosts that still run `unified`, Zao and Aka:
#
#   nix eval --json <cairn>#fleet | jq -S '{builders: (.builders | map_values({system,cpus,maxJobs,speedFactor,features,sshUser,sshPort,hostKey,gate,memoryHigh,memoryMax,managed})), hostKeys, homeMacs, legacyClientKeys}'
#
# Replace the file with that output when a builder or host key changes in
# cairn. Delete this copy when Zao and Aka move to cairn.
builtins.fromJSON (builtins.readFile ./fleet.json)
