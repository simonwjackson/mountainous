{
  config,
  host,
  ...
}: {
  device = {
    id = "DIVKBPA-VNVTEK5-FH7C2SB-QCSK6ZC-N4OE7AQ-3JX63AR-BDR6WMP-JQZ3KAK";
    name = "Desktop (${host})";
  };
  shares = {
    scripts = {
      path = "/home/simonwjackson/.local/scripts";
      versioning = {
        type = "simple";
        params = {
          keep = "5";
        };
      };
      type = "sendreceive";
      copyOwnershipFromParent = true;
    };
    code = {
      path = "/snowscape/code";
      type = "sendreceive";
      # TODO: Make this "global"
      blacklist = [
        # Node.js
        "node_modules/"

        # Build outputs
        "dist/"
        "build/"
        "out/"
        ".next/"
        ".nuxt/"
        ".output/"

        # Environment and config
        ".env.local"
        ".env.*.local"
        "config.local.js"
        "*.local.json"

        # Dependencies and package managers
        "vendor/"
        "composer.phar"
        "Pipfile.lock"
        "poetry.lock"
        "package-lock.json"
        "yarn.lock"
        "pnpm-lock.yaml"

        # IDE and editor files
        ".idea/"
        "*.swp"
        "*.swo"
        ".project"
        ".settings/"
        ".classpath"
        ".factorypath"

        # Testing and coverage
        "coverage/"
        ".nyc_output/"
        ".coverage"
        "htmlcov/"
        ".pytest_cache/"
        "__pycache__/"
        "*.py[cod]"
        ".tox/"

        # Logs and databases
        "*.log"
        "*.sqlite"
        "*.sqlite3"
        "*.db"
        "logs/"
        "*.log.*"

        # Temporary files
        "tmp/"
        "temp/"
        ".temp/"
        "*.tmp"
        "*.bak"
        "*.swp"
        "*.swo"

        # Binary and compiled files
        "*.class"
        "*.dll"
        "*.exe"
        "*.o"
        "*.so"
        "*.dylib"
        "*.jar"
        "*.war"
        "*.ear"
        "*.zip"
        "*.tar.gz"
        "*.rar"

        # Mobile development
        ".gradle/"
        "*.apk"
        "*.aab"
        "*.ipa"
        "*.dSYM.zip"
        "*.dSYM"

        "# Documentation"
        "docs/_build/"
        "site/"

        # Cache
        ".cache/"
        ".parcel-cache/"
        ".eslintcache"
        ".stylelintcache"
        "*.cache"

        # Misc
        "Thumbs.db"
        "ehthumbs.db"
        "*~"
        ".DS_Store"
      ];
    };
    notes = {
      path = "/snowscape/notes";
      type = "sendreceive";
    };
    gaming-profiles = {
      path = "/snowscape/gaming/profiles";
      type = "sendreceive";
    };
    games = {
      path = "/snowscape/gaming/games";
      type = "sendreceive";
      blacklist = [
        "steam/**"
      ];
    };
    videos = {
      path = "/snowscape/videos";
      whitelist = false;
    };
    music = {
      path = "/snowscape/music";
      whitelist = false;
    };
  };
}
