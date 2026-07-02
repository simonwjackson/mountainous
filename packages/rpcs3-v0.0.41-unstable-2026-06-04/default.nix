{
  inputs,
  stdenv,
  ...
}:

let
  pkgs = import inputs.nixpkgs-rpcs3-v0-0-41 {
    system = stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  # RPCS3 v0.0.41 references GLX GLEW extension symbols. The nixpkgs
  # default GLEW build enables EGL, which omits those GLX exports, so use a
  # GLX-enabled GLEW for this source build.
  glewGlx = pkgs.glew.override { enableEGL = false; };
in
(pkgs.rpcs3.override { glew = glewGlx; }).overrideAttrs (_finalAttrs: _previousAttrs: {
  version = "0.0.41-unstable-2026-06-04";

  src = pkgs.fetchFromGitHub {
    owner = "RPCS3";
    repo = "rpcs3";
    rev = "40e9ee5af0de7ca31691c58eebe64ba205a2900b";
    postCheckout = ''
      cd $out/3rdparty
      git submodule update --init \
        fusion/fusion asmjit/asmjit yaml-cpp/yaml-cpp SoundTouch/soundtouch stblib/stb \
        feralinteractive/feralinteractive wolfssl/wolfssl
    '';
    hash = "sha256-d28DlmYchCU0QvFFhyf1GHx9NgcUX4zZ0XpV8/O6vJc=";
  };
})
