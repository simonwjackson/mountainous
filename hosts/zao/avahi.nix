{
  inputs,
  pkgs,
  ...
}: {
  # Import only the current Avahi recipe. All dependencies still come from the
  # shared Nixpkgs pin, and every other host keeps its existing Avahi package.
  services.avahi.package = (pkgs.callPackage inputs.avahi-package-recipe.outPath {}).overrideAttrs (old: {
    patches = old.patches ++ [inputs.avahi-timeout-fix.outPath];
    # Without this flag, `make check` succeeds but runs zero tests.
    configureFlags = old.configureFlags ++ ["--enable-tests"];
    doCheck = true;
    postCheck =
      (old.postCheck or "")
      + ''
        ./avahi-common/strlst-test
        ./avahi-common/domain-test
        ./avahi-common/alternative-test
        ./avahi-common/timeval-test
        ./avahi-common/utf8-test
      '';
  });
}
