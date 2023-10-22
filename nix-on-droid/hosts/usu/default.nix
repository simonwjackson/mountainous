{ config, lib, pkgs, ... }:

{
  # TODO: Remote building
  # https://github.com/nix-community/nix-on-droid/issues/62

  imports = [
    ./sshd.nix
  ];

  # HACK: DNS ersolution fix
  # https://github.com/ettom/dnshack
  home.file.".bashrc".text =
    let dnshack = pkgs.callPackage (builtins.fetchTarball "https://github.com/ettom/dnshack/tarball/master") { };
    in ''
      export DNSHACK_RESOLVER_CMD="${dnshack}/bin/dnshackresolver"
      export LD_PRELOAD="${dnshack}/lib/libdnshackbridge.so"
    '';

  # Simply install just the packages
  environment.packages = with pkgs; [
    # User-facing stuff that you really really want to have
    vim # or some other editor, e.g. nano or neovim
    git
    openssh
    # Some common stuff that people expect to have
    #diffutils
    #findutils
    #utillinux
    #tzdata
    #hostname
    #man
    #gnugrep
    #gnupg
    #gnused
    #gnutar
    #bzip2
    #gzip
    #xz
    #zip
    #unzip
  ];

  # Backup etc files instead of failing to activate generation if a file already exists in /etc
  environment.etcBackupExtension = ".bak";

  # Read the changelog before changing this value
  system.stateVersion = "23.05";

  # Set up nix for flakes
  nix.extraOptions = ''
    experimental-features = nix-command flakes
  '';

  # Set your time zone
  #time.timeZone = "Europe/Berlin";

}
