{ lib, buildGoModule, fetchFromGitHub, fetchurl, stdenv, ... }:

let
  version = "0.11.0";
  
  # Try building from source first
  sourcePackage = buildGoModule {
    pname = "gogcli";
    inherit version;

    src = fetchFromGitHub {
      owner = "steipete";
      repo = "gogcli";
      rev = "v${version}";
      sha256 = lib.fakeSha256;  # Will need to be updated after first build attempt
    };

    vendorHash = lib.fakeSha256;  # Will need to be updated after first build attempt

    meta = with lib; {
      description = "Google APIs CLI tool";
      homepage = "https://github.com/steipete/gogcli";
      license = licenses.mit;
      maintainers = [ ];
      platforms = platforms.linux;
      mainProgram = "gog";
    };
  };

  # Fallback to prebuilt binary if source build fails
  prebuiltPackage = stdenv.mkDerivation {
    pname = "gogcli";
    inherit version;
    
    src = fetchurl {
      url = "https://github.com/steipete/gogcli/releases/download/v${version}/gogcli_${version}_linux_arm64.tar.gz";
      sha256 = "0dfxxw0cgnkj8mbmya058qmcfwb6qxpwd4zdix4025b48l2rizhv";
    };

    sourceRoot = ".";
    
    installPhase = ''
      mkdir -p $out/bin
      cp gog $out/bin/
      chmod +x $out/bin/gog
    '';
    
    meta = with lib; {
      description = "Google APIs CLI tool (prebuilt binary)";
      homepage = "https://github.com/steipete/gogcli";
      license = licenses.mit;
      maintainers = [ ];
      platforms = [ "aarch64-linux" ];
      mainProgram = "gog";
    };
  };

in
# Try source first, fall back to prebuilt
# For now, let's use prebuilt since the task mentions compile issues
prebuiltPackage