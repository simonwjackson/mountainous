{
  config,
  host,
  ...
}: {
  device = {
    id = "ABVHUQR-BIPNGCS-W7RGGEV-HBA3R4C-UWQAYWQ-KCBPJ6D-PIPLQYU-CXHOWAD";
    name = "Laptop (${host})";
  };
  shares = {
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
  };
}
