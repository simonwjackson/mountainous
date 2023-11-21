# Add your reusable NixOS modules to this directory, on their own file (https://nixos.wiki/wiki/Module).
# These should be stuff you would like to share with others, not your personal configurations.
{
  vpn-proxy = import ./vpn-proxy.nix;
  cuttlefish = import ./cuttlefish.nix;
  sunshine = import ./sunshine.nix;
  tailscaled = import ./tailscaled.nix;
}
