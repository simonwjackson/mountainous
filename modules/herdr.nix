# herdr, the multiplexer the terminal overlay runs.
#
# herdr is "the runtime your coding agents live on": one terminal UI holding
# sessions, tabs and agents, which keep running when the client detaches. That
# is why the overlay in modules/hyprland.nix runs it rather than a shell.
# Closing the overlay window costs nothing, because the session is on the
# server side and the next launch attaches to it.
#
# It is not in nixpkgs, so this installs the upstream v0.9.0 release.
#
# Packaging is this short because the binary asks for nothing. Measured on the
# published herdr-linux-x86_64 with file(1) and patchelf:
#
#   ELF 64-bit LSB pie executable, x86-64, static-pie linked
#   --print-interpreter  -> no .interp section, statically linked
#   --print-needed       -> no shared libraries
#
# A static-pie binary with no interpreter and no NEEDED entries runs on NixOS
# unmodified, so there is no autoPatchelfHook, no wrapper and no
# buildFHSUserEnv here. Installing the file IS the package. If a later release
# gains a dynamic interpreter, that stops being true and this needs
# autoPatchelfHook; the check is `patchelf --print-interpreter`.
#
# Built from the release rather than from source on purpose. Source would mean
# a full cargo build of a large Rust tree for a binary upstream already
# publishes, and the trade is stated plainly: this is a prebuilt blob, trusted
# because flake.lock pins its hash, not because Nix built it.
#
# x86_64-linux only. ridge is the only host, and it is x86_64. The input in
# flake.nix names that asset directly, so an aarch64 host needs a second input
# and a platform switch here rather than a silent wrong-architecture install.
{ inputs, ... }:
{
  nixos.modules.desktop =
    { pkgs, lib, ... }:
    let
      herdr = pkgs.runCommand "herdr-0.9.0" {
        meta = {
          description = "The runtime your coding agents live on";
          homepage = "https://herdr.dev";
          license = lib.licenses.asl20;
          platforms = [ "x86_64-linux" ];
          mainProgram = "herdr";
        };
      } ''
        install -Dm755 ${inputs.herdr-bin} $out/bin/herdr
      '';
    in
    {
      assertions = [
        {
          assertion = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
          message = ''
            modules/herdr.nix installs the x86_64 herdr release, but this host is
            ${pkgs.stdenv.hostPlatform.system}. Add the matching release asset as a
            flake input and select on the platform here.
          '';
        }
      ];

      environment.systemPackages = [ herdr ];
    };
}
