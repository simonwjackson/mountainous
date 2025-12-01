# Patch flexget to include the web UI assets built from source
final: prev: {
  flexget = prev.flexget.overridePythonAttrs (old: {
    postInstall =
      (old.postInstall or "")
      + ''
        # Install web UI assets
        mkdir -p $out/${prev.python3.sitePackages}/flexget/ui/v2/dist
        cp -r ${final.flexget-webui}/* $out/${prev.python3.sitePackages}/flexget/ui/v2/dist/
      '';
  });
}
