{
  bash,
  coreutils,
  fd,
  findutils,
  fzf,
  gawk,
  gnused,
  jq,
  nettools,
  pkgs,
  resholve,
  stdenv,
  tmux,
}:
resholve.mkDerivation {
  pname = "nest-tmux";
  version = "unstable";
  src = ./src;

  postPatch = ''
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    find $src -type f -exec bash -c 'file="$1"; install -Dm 755 "$file" "$out/''${file#$src/}"' -- {} \;

    substituteInPlace $out/bin/* \
      --replace /etc/nest-tmux $out/etc/nest-tmux

    mkdir -p $out/etc/nest-tmux
    cp $src/etc/nest-tmux/*.tmux.conf $out/etc/nest-tmux

    runHook postInstall
  '';

  solutions = {
    default = {
      scripts = [
        "bin/*"
      ];
      interpreter = "${bash}/bin/bash";
      inputs = [
        tmux
        fzf
        coreutils
        gnused
        jq
        fd
        findutils
        bash
        gawk
        nettools
      ];
      fake = {
        external = [
          # Make sure we can self reference our scripts
          "nest-tmux-local-instance"
          "nest-tmux-remote-instance"
          "nest-tmux-choose-host"
          "nest-tmux-choose-session"
        ];
      };
      execer = [
        # resholve cannot verify args from these apps
        "cannot:${tmux}/bin/tmux"
        "cannot:${fzf}/bin/fzf"
        "cannot:${fd}/bin/fd"
      ];
    };
  };

  # meta = with lib; {
  #   homepage = "https://github.com/intel/S0ixSelftestTool";
  #   description = "A tool for testing the S2idle path CPU Package C-state and S0ix failures";
  #   license = licenses.gpl2Only;
  #   platforms = platforms.linux;
  # };
}
# let
#   host-config = pkgs.writeTextDir "etc/nest-tmux/host.config.tmux.conf" (builtins.readFile ./src/etc/nest-tmux/host.tmux.conf);
#   remote-config = pkgs.writeTextDir "etc/nest-tmux/remote.config.tmux.conf" (builtins.readFile ./src/etc/nest-tmux/remote.tmux.conf);
#   nest-tmux-local-instance = pkgs.resholve.writeScriptBin "nest-tmux-local-instance"
#     {
#       interpreter = "${pkgs.bash}/bin/bash";
#       inputs = with pkgs; [ tmux host-config remote-config ];
#       execer = with pkgs; [
#         "cannot:${tmux}/bin/tmux"
#       ];
#       patchPhase = ''
#         rm $out
#       '';
#     }
#     (builtins.readFile ./src/bin/nest-tmux-local-instance.sh);
# in
# pkgs.symlinkJoin {
#   name = "nest-tmux";
#   paths = [
#     nest-tmux-local-instance
#     host-config
#     remote-config
#   ];
# }
# stdenv.mkDerivation rec {
#   name = "nest-tmux";
#   src = ./src;
#   buildInputs = with pkgs; [ tmux boxes fzf fd ];
#   # phases = [ "installPhase" ];
#   # dontBuild = true;
#   patchPhase = ''
#     # use `install`?
#     # copy all files then modify
#     # installing
#     cp -r $src $out
#     # mkdir -p $out/bin
#     # rm $out/bin/nest-tmux-choose-host.sh
#     # ${pkgs.patsh}/bin/patsh -f $out/bin/nest-tmux-choose-host.sh
#     # ${pkgs.patsh}/bin/patsh $src/bin/nest-tmux-choose-host.sh $out/bin/nest-tmux-choose-host.sh
#
#     # substituteInPlace $out/bin/nest-tmux \
#     #   --replace /etc/nest-tmux $out/etc/nest-tmux
#     # patchShebangs $out/bin/*
#     # ${pkgs.shellcheck}/bin/shellcheck $out/bin/*
#     # chmod +x $out/bin/*
#
#     # ${pkgs.patsh}/bin/patsh $src/tmux-local-sessions.sh $out/bin/tmux-local-sessions
#     # substituteInPlace $out/bin/tmux-local-sessions \
#     #   --replace /etc/nest-tmux $out/etc/nest-tmux
#     # patchShebangs $out/bin/tmux-local-sessions
#     # # ${pkgs.shellcheck}/bin/shellcheck -e SC2016 $out/bin/tmux-local-sessions
#     # chmod +x $out/bin/tmux-local-sessions
#
#     # ${pkgs.patsh}/bin/patsh $src/tmux-start-remote-instance.sh $out/bin/tmux-start-remote-instance
#     # substituteInPlace $out/bin/tmux-start-remote-instance \
#     #   --replace /etc/nest-tmux $out/etc/nest-tmux
#     # patchShebangs $out/bin/tmux-start-remote-instance
#     # # ${pkgs.shellcheck}/bin/shellcheck -e SC2016 $out/bin/tmux-start-remote-instance
#     # chmod +x $out/bin/tmux-start-remote-instance
#
#     # ${pkgs.patsh}/bin/patsh $src/tmux-connect-server.sh $out/bin/tmux-connect-server
#     # substituteInPlace $out/bin/tmux-connect-server \
#     #   --replace /etc/nest-tmux $out/etc/nest-tmux
#     # patchShebangs $out/bin/tmux-connect-server
#     # chmod +x $out/bin/tmux-connect-server
#
#     # mkdir -p $out/etc/nest-tmux
#     # cp $src/*.tmux.conf $out/etc/nest-tmux
#   '';
# }

