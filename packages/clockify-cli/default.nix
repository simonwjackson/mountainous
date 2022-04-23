{ libs, config, pkgs, ... }:

let
  version = "0.32.2";
  name = "clockify-cli";

  app = pkgs.stdenv.mkDerivation {
    version = version;
    pname = nname;

    src = pkgs.fetchurl {
      curlOpts = [ "-L" "-H" "Accept:application/octet-stream" ];
      url = "https://github.com/lucassabreu/clockify-cli/releases/download/v0.32.2/clockify-cli_0.32.2_Linux_x86_64.tar.gz";
      sha256 = "sha256-ACnEdFHiRplJTZtntCfLPPeViMrB0iiCf0HuQQHHShs=";
    };

    # Work around the "unpacker appears to have produced no directories"
    # case that happens when the archive doesn't have a subdirectory.
    setSourceRoot = "sourceRoot=`pwd`";


    installPhase = ''
      mkdir -p $out/bin
      cp clockify-cli $out/bin
    '';
  };

in
{
  environment.systemPackages = [
    app
  ];
}
