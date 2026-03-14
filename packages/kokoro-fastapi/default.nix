{
  lib,
  python312,
  fetchFromGitHub,
  fetchurl,
  espeak-ng,
  ffmpeg,
  libsndfile,
  makeWrapper,
  stdenv,
  cudaSupport ? false,
  cudaPackages ? null,
  ...
}: let
  # Fetch the pre-trained Kokoro model
  kokoroModel = fetchurl {
    url = "https://github.com/remsky/Kokoro-FastAPI/releases/download/v0.1.4/kokoro-v1_0.pth";
    hash = "sha256-SW26EY0aWPXz2y78iNvcIW4Eg/yJ/m5H7h8sU/GK0eQ=";
  };

  # Create Python environment with all dependencies
  # Override to resolve typer/typer-slim conflict
  pythonWithOverrides = python312.override {
    packageOverrides = self: super: {
      # Override weasel to use typer instead of typer-slim
      weasel = super.weasel.overridePythonAttrs (old: {
        dependencies = builtins.map (
          dep:
            if dep == super.typer-slim
            then super.typer
            else dep
        ) (old.dependencies or []);
        # Disable runtime dependency checking for this package
        pythonRemoveDeps = (old.pythonRemoveDeps or []) ++ ["typer-slim"];
        pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["typer-slim"];
      });
      # Override spacy to use typer instead of typer-slim
      spacy = super.spacy.overridePythonAttrs (old: {
        dependencies = builtins.map (
          dep:
            if dep == super.typer-slim
            then super.typer
            else dep
        ) (old.dependencies or []);
        pythonRemoveDeps = (old.pythonRemoveDeps or []) ++ ["typer-slim"];
        pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["typer-slim"];
      });
    };
  };

  pythonEnv = pythonWithOverrides.withPackages (ps:
    with ps;
      [
        # Web framework
        fastapi
        uvicorn
        click
        pydantic
        pydantic-settings
        python-dotenv
        sqlalchemy

        # Audio processing
        numpy
        scipy
        soundfile
        pydub
        av # FFmpeg bindings
        mutagen

        # TTS core (now in nixpkgs!)
        kokoro
        misaki

        # NLP and text processing
        spacy
        spacy-transformers
        spacy-models.en_core_web_sm # Required by misaki/kokoro
        inflect
        phonemizer
        regex
        # text2num - not in nixpkgs, may need to package separately

        # Utilities
        aiofiles
        tqdm
        requests
        tiktoken
        loguru
        openai
        munch
        matplotlib
        psutil

        # Torch - CPU or CUDA variant
      ]
      ++ lib.optionals (!cudaSupport) [
        torch
      ]
      ++ lib.optionals cudaSupport [
        torch-bin
      ]);
in
  stdenv.mkDerivation rec {
    pname = "kokoro-fastapi";
    version = "0.3.0";

    src = fetchFromGitHub {
      owner = "remsky";
      repo = "Kokoro-FastAPI";
      rev = "311ee6497b05dc904e505ba302048d08ba70c2ba";
      hash = "sha256-XXXfobS41yp2pm+6VG4AiE5DW9K9ohnNypFMQzgpQnU=";
    };

    nativeBuildInputs = [makeWrapper];

    buildInputs =
      [
        pythonEnv
        espeak-ng
        ffmpeg
        libsndfile
      ]
      ++ lib.optionals cudaSupport [
        cudaPackages.cudatoolkit
      ];

    # Don't run the build phase - we're just installing the Python files
    dontBuild = true;

    installPhase = ''
      runHook preInstall

      # Create the application directory as a Python package
      mkdir -p $out/share/kokoro-fastapi/api_server

      # Copy the API source code into a package
      cp -r api/src/* $out/share/kokoro-fastapi/api_server/

      # Create __init__.py to make it a proper package
      touch $out/share/kokoro-fastapi/api_server/__init__.py

      # Install the pre-trained model
      mkdir -p $out/share/kokoro-fastapi/api_server/models/v1_0
      cp ${kokoroModel} $out/share/kokoro-fastapi/api_server/models/v1_0/kokoro-v1_0.pth

      # Copy voice files (included in repo)
      mkdir -p $out/share/kokoro-fastapi/api_server/voices
      cp -r api/src/voices/* $out/share/kokoro-fastapi/api_server/voices/

      # Copy web player UI
      mkdir -p $out/share/kokoro-fastapi/web
      cp -r web/* $out/share/kokoro-fastapi/web/

      # Create wrapper script that runs uvicorn with the package path
      mkdir -p $out/bin
      makeWrapper ${pythonEnv}/bin/python $out/bin/kokoro-fastapi \
        --add-flags "-m uvicorn api_server.main:app --host 0.0.0.0 --port 8880" \
        --chdir "$out/share/kokoro-fastapi" \
        --prefix PATH : ${lib.makeBinPath [espeak-ng ffmpeg]} \
        --prefix PYTHONPATH : "$out/share/kokoro-fastapi" \
        --set PHONEMIZER_ESPEAK_PATH "${espeak-ng}/bin/espeak-ng" \
        --set ESPEAK_DATA_PATH "${espeak-ng}/share/espeak-ng-data" \
        --set MODEL_DIR "$out/share/kokoro-fastapi/api_server/models" \
        --set VOICES_DIR "$out/share/kokoro-fastapi/api_server/voices/v1_0" \
        --set OUTPUT_DIR "/tmp/kokoro-output" \
        --set TEMP_FILE_DIR "/tmp/kokoro-temp" \
        --set WEB_PLAYER_PATH "$out/share/kokoro-fastapi/web" \
        ${lib.optionalString cudaSupport "--set USE_GPU true --set DEVICE_TYPE cuda"} \
        ${lib.optionalString (!cudaSupport) "--set USE_GPU false"}

      runHook postInstall
    '';

    meta = with lib; {
      description = "GPU-accelerated text-to-speech API using Kokoro TTS";
      longDescription = ''
        Kokoro-FastAPI is a FastAPI-based TTS backend using the Kokoro TTS model.
        It provides OpenAI-compatible endpoints for text-to-speech generation with
        support for multiple voices and optional CUDA acceleration.

        Features:
        - OpenAI-compatible API endpoints
        - Multiple voice options with customizable parameters
        - Optional CUDA/GPU acceleration for faster inference
        - Support for various audio formats and sample rates
        - Built-in phonemization using espeak-ng
      '';
      homepage = "https://github.com/remsky/Kokoro-FastAPI";
      license = licenses.asl20;
      platforms = platforms.linux;
      maintainers = [];
    };
  }
