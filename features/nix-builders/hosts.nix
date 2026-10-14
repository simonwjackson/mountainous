# Central registry of Nix build machines.
#
# An entry states what a machine can build, not who may use it. Reachability is a
# property of a pair of machines — the client's root needs a key the builder
# accepts — so each host names the builders it can actually reach in
# mountainous.features.nix-builders.use.
#
# Fuji is not yet a client of anything: its root has no SSH client key, so it
# cannot log in to Zao. Giving it one is a separate change with new key material.
{
  fuji = {
    system = "aarch64-linux";
    sshUser = "simonwjackson";
    maxJobs = 4;
    speedFactor = 1;
    # This Oracle ARM instance has no /dev/kvm, so it must not be offered work
    # that needs virtualisation — a nixos-test sent here fails rather than waits.
    supportedFeatures = ["big-parallel" "benchmark"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU1LZE5aYjZxbmNTSGNBTEZ4dHpBRENEU0V0KzAzVkxoUlFtTlNuK3JIYTIgcm9vdEBmdWppCg==";
  };

  # Yari runs cairn (modules/builder.nix): user simon, and Zao's root key may
  # only run nix-daemon --stdio, so the protocol must stay ssh-ng. Its daemon
  # runs at idle priority behind Forgerie, and it has no /dev/kvm either.
  yari = {
    system = "aarch64-linux";
    sshUser = "simon";
    maxJobs = 4;
    speedFactor = 1;
    supportedFeatures = ["big-parallel" "benchmark"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUl2Y2ZQTUQ4aUF2eHdXQThFcGZrOTVDdnN6anpzUVNEcGV0a2pnZFBaUGggcm9vdEB5YXJpCg==";
  };

  zao = {
    system = "x86_64-linux";
    sshUser = "simonwjackson";
    maxJobs = 16;
    speedFactor = 4;
    supportedFeatures = ["big-parallel" "benchmark" "kvm" "nixos-test"];
    publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUN1VmZOd25EYmZuY2ZKbjBybXhucGJ1STRBdXd3VElOYzg2NGVzU2ptcXYgcm9vdEB6YW8K";
  };
}
