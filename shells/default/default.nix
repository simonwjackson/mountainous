{pkgs, ...}:
pkgs.mkShell {
  NIX_CONFIG = "extra-experimental-features = nix-command flakes";
  buildInputs = with pkgs; [
    age
    btrfs-progs
    disko
    efibootmgr
    git
    just
    ssh-to-age
    util-linux
  ];
}
