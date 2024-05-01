{
  config,
  inputs,
  lib,
  rootPath,
  ...
}: {
  nix = {
    # gc = {
    #   automatic = true;
    #   dates = "weekly";
    #   # Keep the last 3 generations
    #   options = "--delete-older-than +3";
    # };

    buildMachines = [
      # {
      #   hostName = "zao";
      #   sshUser = "simonwjackson";
      #   system = "x86_64-linux";
      #   protocol = "ssh-ng";
      #   maxJobs = 12;
      #   speedFactor = 10;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
      # {
      #   hostName = "unzen";
      #   sshUser = "simonwjackson";
      #   system = "x86_64-linux";
      #   protocol = "ssh-ng";
      #   maxJobs = 6;
      #   speedFactor = 9;
      #   supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
      #   mandatoryFeatures = [];
      # }
      # {
      #   hostName = "kita";
      #   system = "x86_64-linux";
      #   maxJobs = 0;
      # }
    ];
  };
}
