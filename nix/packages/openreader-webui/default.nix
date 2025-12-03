{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchurl,
  nodejs_22,
  pnpm_9,
  ffmpeg,
  whisper-cpp,
  makeWrapper,
  ...
}: let
  # Whisper model for word-level alignment
  whisperModel = fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.en.bin";
    hash = "sha256-kh5M+Ghv3Zk9zQgaXaW2w2W/3hFi5ysI11rHUomSCx8=";
  };
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "openreader-webui";
    version = "unstable-2025-11-22";

    src = fetchFromGitHub {
      owner = "richardr1126";
      repo = "OpenReader-WebUI";
      rev = "30ade1d79a06cb137ba330279cd3251a9756f9cd";
      hash = "sha256-qez5ltQSPxvJ7KRbvCl+TmwME1SpjGOoyMwnV9WO4L4=";
    };

    nativeBuildInputs = [
      nodejs_22
      pnpm_9.configHook
      makeWrapper
    ];

    pnpmDeps = pnpm_9.fetchDeps {
      inherit (finalAttrs) pname version src;
      hash = "sha256-l+GJ2TIqUDTBgjl5FHAfsnee9b/EbhEZVwD8kEUitwI=";
      fetcherVersion = 1;
    };

    # Next.js needs this for standalone builds
    env = {
      NEXT_TELEMETRY_DISABLED = "1";
    };

    # Patch next.config to enable standalone output
    postPatch = ''
          rm -f next.config.ts next.config.mjs next.config.js
          cat > next.config.js << 'EOF'
      /** @type {import('next').NextConfig} */
      const nextConfig = {
        output: 'standalone',
        turbopack: {
          resolveAlias: {
            canvas: './empty-module.ts',
          },
        },
      };

      module.exports = nextConfig;
      EOF
    '';

    buildPhase = ''
      runHook preBuild
      pnpm run build
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall

      mkdir -p $out/share/openreader-webui

      # Copy standalone build (server.js, .next with server files)
      cp -rL .next/standalone/. $out/share/openreader-webui/

      # Replace minimal node_modules with full one (pnpm symlink structure required)
      rm -rf $out/share/openreader-webui/node_modules
      cp -a node_modules $out/share/openreader-webui/

      # Add static files (not included in standalone output)
      mkdir -p $out/share/openreader-webui/.next/static
      cp -r .next/static/* $out/share/openreader-webui/.next/static/

      # Copy public assets
      cp -r public $out/share/openreader-webui/

      # Bundle whisper model for word-level alignment
      mkdir -p $out/share/openreader-webui/docstore/model
      cp ${whisperModel} $out/share/openreader-webui/docstore/model/ggml-tiny.en.bin

      mkdir -p $out/bin
      makeWrapper ${nodejs_22}/bin/node $out/bin/openreader-webui \
        --add-flags "$out/share/openreader-webui/server.js" \
        --prefix PATH : ${lib.makeBinPath [ffmpeg whisper-cpp]} \
        --set NODE_ENV production \
        --set WHISPER_CPP_BIN "${whisper-cpp}/bin/whisper-cli" \
        --chdir "$out/share/openreader-webui"

      runHook postInstall
    '';

    meta = with lib; {
      description = "Web-based EPUB/PDF reader with text-to-speech";
      homepage = "https://github.com/richardr1126/OpenReader-WebUI";
      license = licenses.mit;
      platforms = platforms.linux;
    };
  })
