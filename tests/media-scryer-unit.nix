{ pkgs }:
pkgs.runCommand "media-scryer-unit" { nativeBuildInputs = [ pkgs.python3 ]; } ''
  mkdir -p fixture/scripts/fixtures fixture/modules
  cp ${../scripts/media-scryer-common.py} fixture/scripts/media-scryer-common.py
  cp ${../scripts/media-scryer-parity.py} fixture/scripts/media-scryer-parity.py
  cp ${../scripts/media-scryer-provision.py} fixture/scripts/media-scryer-provision.py
  cp ${../scripts/media-scryer-import.py} fixture/scripts/media-scryer-import.py
  cp ${../scripts/media-arr-archive.py} fixture/scripts/media-arr-archive.py
  cp ${../scripts/media-scryer-indexer-audit.py} fixture/scripts/media-scryer-indexer-audit.py
  cp ${../scripts/media-library-snapshot.py} fixture/scripts/media-library-snapshot.py
  cp ${../scripts/test-media-scryer.py} fixture/scripts/test-media-scryer.py
  cp ${../scripts/fixtures/media-scryer-parity.json} fixture/scripts/fixtures/media-scryer-parity.json
  cp ${../modules/media-state-ready.py} fixture/modules/media-state-ready.py
  cp ${../modules/media-arr-state-ready.py} fixture/modules/media-arr-state-ready.py
  python3 fixture/scripts/test-media-scryer.py
  touch "$out"
''
