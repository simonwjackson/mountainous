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
# Upstream publishes one binary per architecture, so this picks by host
# platform. The static-pie reasoning above was checked on the x86_64 asset;
# the aarch64 asset is assumed to be built the same way by the same release
# job, which is an assumption, not a measurement. If herdr fails to run on
# an aarch64 host, `patchelf --print-interpreter` on the installed file is the check.
{ inputs, ... }:
{
  nixos.modules.desktop =
    { pkgs, lib, ... }:
    let
      # Named by the Nix system string so a new platform fails as a missing
      # attribute here, naming the platform, rather than installing a binary
      # for the wrong architecture.
      binaries = {
        "x86_64-linux" = inputs.herdr-bin-x86_64;
        "aarch64-linux" = inputs.herdr-bin-aarch64;
      };

      inherit (pkgs.stdenv.hostPlatform) system;

      herdr = pkgs.runCommand "herdr-0.9.0" {
        meta = {
          description = "The runtime your coding agents live on";
          homepage = "https://herdr.dev";
          license = lib.licenses.asl20;
          platforms = lib.attrNames binaries;
          mainProgram = "herdr";
        };
      } ''
        install -Dm755 ${binaries.${system}} $out/bin/herdr
      '';
    in
    {
      assertions = [
        {
          assertion = binaries ? ${system};
          message = ''
            modules/herdr.nix has no herdr release for ${system}.
            Add the matching asset from
            https://github.com/herdrdev/herdr/releases/tag/v0.9.0
            as a flake input and list it in `binaries` here.
          '';
        }
      ];

      environment.systemPackages = [ herdr ];
    };
}
