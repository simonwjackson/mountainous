# nix-instantiate --json --eval -E 'builtins.toJSON (import ./hosts.nix)' | jq -r
{
  hosts = {
    fiji = {
      os = "nixos";
    };
  };
}
