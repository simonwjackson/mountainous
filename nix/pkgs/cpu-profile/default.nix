{
  bash,
  coreutils,
  pkgs,
  resholve,
  stdenv,
  gnugrep,
  coreutils-full,
}:
resholve.mkDerivation {
  pname = "cpu-profile";
  version = "unstable";
  src = ./src;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    find $src -type f -exec bash -c 'file="$1"; install -Dm 755 "$file" "$out/''${file#$src/}"' -- {} \;

    runHook postInstall
  '';

  solutions = {
    default = {
      scripts = [
        "bin/*"
      ];
      interpreter = "${bash}/bin/bash";
      inputs = [
        pkgs.linuxKernel.packages.linux_zen.cpupower
        gnugrep
        coreutils-full
      ];
      fake = {
        external = [
          # Make sure we can self reference our scripts
        ];
      };
      execer = [
        # resholve cannot verify args from these apps
        "cannot:${pkgs.linuxKernel.packages.linux_zen.cpupower}/bin/cpupower"
        # "cannot:${fzf}/bin/fzf"
        # "cannot:${fd}/bin/fd"
      ];
    };
  };
}
