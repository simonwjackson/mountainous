{ pkgs }:

let
  # Helper: wrap a shell script with runtime deps
  mkShellScript = name: { deps, text }: pkgs.writeShellApplication {
    inherit name text;
    runtimeInputs = deps;
    excludeShellChecks = [ "SC1090" "SC1091" "SC2094" "SC2155" "SC2086" "SC2034" "SC2001" "SC2188" ];
  };

  # Helper: wrap a python3 script with optional packages
  mkPythonScript = name: { pythonDeps ? (_: []), scriptPath }: let
    python = pkgs.python3.withPackages pythonDeps;
  in pkgs.stdenv.mkDerivation {
    inherit name;
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/bin
      cp ${scriptPath} $out/bin/${name}
      chmod +x $out/bin/${name}
      # Patch shebang to use our python with deps
      substituteInPlace $out/bin/${name} \
        --replace-quiet '#!/usr/bin/env python3' '#!${python}/bin/python3'
    '';
    # Add shebang if missing
    postFixup = ''
      if ! head -1 $out/bin/${name} | grep -q '^#!'; then
        echo '#!${python}/bin/python3' | cat - $out/bin/${name} > $out/bin/${name}.tmp
        mv $out/bin/${name}.tmp $out/bin/${name}
        chmod +x $out/bin/${name}
      fi
    '';
  };

in {
  # === BIOMETRICS ===

  biometrics-oura-sync = mkShellScript "biometrics-oura-sync" {
    deps = with pkgs; [ curl jq coreutils util-linux ];
    text = builtins.readFile ./biometrics-oura-sync.sh;
  };

  biometrics-withings-sync = mkShellScript "biometrics-withings-sync" {
    deps = with pkgs; [ curl jq coreutils python3 util-linux ];
    text = builtins.readFile ./biometrics-withings-sync.sh;
  };

  biometrics-ketomojo-sync = mkShellScript "biometrics-ketomojo-sync" {
    deps = with pkgs; [ curl jq coreutils python3 util-linux ];
    text = builtins.readFile ./biometrics-ketomojo-sync.sh;
  };

  biometrics-import-saa = mkPythonScript "biometrics-import-saa" {
    scriptPath = ./biometrics-import-saa.py;
  };

  biometrics-withings-auth = mkPythonScript "biometrics-withings-auth" {
    scriptPath = ./biometrics-withings-auth.py;
  };

  # === FITNESS ===

  fitness-import = mkPythonScript "fitness-import" {
    scriptPath = ./fitness-import.py;
  };

  # === NUTRITION ===

  nutrition-lookup = mkShellScript "nutrition-lookup" {
    deps = with pkgs; [ curl jq yq ];
    text = builtins.readFile ./nutrition-lookup.sh;
  };

  nutrition-log-meal = mkShellScript "nutrition-log-meal" {
    deps = with pkgs; [ jq yq coreutils ];
    text = builtins.readFile ./nutrition-log-meal.sh;
  };

  nutrition-daily-summary = mkShellScript "nutrition-daily-summary" {
    deps = with pkgs; [ jq yq coreutils (python3.withPackages (ps: [ ps.pyyaml ])) ];
    text = builtins.readFile ./nutrition-daily-summary.sh;
  };

  # === TASKS ===

  tasks-query = mkShellScript "tasks-query" {
    deps = with pkgs; [ bun ];
    text = builtins.readFile ./tasks-query.sh;
  };

  # === OMI ===

  omi-pipeline = mkShellScript "omi-pipeline" {
    deps = with pkgs; [ curl jq coreutils gnused util-linux ];
    text = builtins.readFile ./omi-pipeline.sh;
  };

  omi-cron = mkShellScript "omi-cron" {
    deps = with pkgs; [ ];
    text = builtins.readFile ./omi-cron.sh;
  };

  # === KROGER ===

  kroger-lib = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.stdenv.mkDerivation {
    name = "kroger-lib";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/lib/python3/site-packages
      cp ${./kroger-lib.py} $out/lib/python3/site-packages/kroger.py
    '';
  };

  kroger-weekly-deals = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger-weekly-deals";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-weekly-deals.py} "$@"
    '';
  };

  kroger-weekly-keto = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger-weekly-keto";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-weekly-keto.py} "$@"
    '';
  };

  kroger-add-to-cart = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger-add-to-cart";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-add-to-cart.py} "$@"
    '';
  };

  kroger-analyze-prices = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger-analyze-prices";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-analyze-prices.py} "$@"
    '';
  };

  kroger-fix-search = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger-fix-search";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-fix-search.py} "$@"
    '';
  };

  kroger = let
    python = pkgs.python3.withPackages (ps: [ ps.requests ]);
  in pkgs.writeShellApplication {
    name = "kroger";
    runtimeInputs = [ python ];
    text = ''
      export PYTHONPATH="${pkgs.lifted-scripts.kroger-lib}/lib/python3/site-packages:''${PYTHONPATH:-}"
      exec ${python}/bin/python3 ${./kroger-lib.py} "$@"
    '';
  };

  # === EBAY ===

  ebay-api = mkShellScript "ebay-api" {
    deps = with pkgs; [ coreutils jq ];
    text = builtins.readFile ./ebay-api.sh;
  };

  ebay-publish = mkShellScript "ebay-publish" {
    deps = with pkgs; [ curl jq coreutils gnused findutils ];
    text = builtins.readFile ./ebay-publish.sh;
  };

  # === YOUTUBE ===

  youtube-digest = mkShellScript "youtube-digest" {
    deps = with pkgs; [ curl jq coreutils gnused gnugrep ];
    text = builtins.readFile ./youtube-digest.sh;
  };

}
