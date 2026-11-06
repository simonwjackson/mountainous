{ inputs, ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.gogcli = pkgs.callPackage ../packages/gogcli {
        src = inputs."gogcli-${pkgs.stdenv.hostPlatform.system}-src";
      };
    };
}
