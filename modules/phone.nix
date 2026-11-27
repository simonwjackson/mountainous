{ ... }:
{
  nixos.modules.phone =
    {
      pkgs,
      config,
      lib,
      ...
    }:
    {
      mountainous.beszel.enable = false; # no device token before enrollment
      boot.plymouth.theme = lib.mkForce "mountainous-twin";
      boot.plymouth.extraConfig = "DeviceScale=1";
      boot.plymouth.themePackages = [
        (pkgs.runCommand "mountainous-twin-plymouth" { } ''
          dir=$out/share/plymouth/themes/mountainous-twin
          mkdir -p "$dir"
          cp ${./desktop-boot/mountainous-twin}/* "$dir/"
          substituteInPlace "$dir/mountainous-twin.plymouth" --replace-fail /usr/share/plymouth "$out/share/plymouth"
        '')
      ];
      environment.systemPackages = [ config.system.build.hensouKit ];
      services.korriProduct.runtimeAccount.uid = 56774;
      # Do not claim Denial's seat. Nested Sway and the mode switch are later work.
      services.korriLinuxHost.compositor = {
        backend = "headless";
        allowedInputIdentifiers = lib.mkForce [ ];
        localInput.enable = false;
        renderDevice = "/dev/dri/renderD128";
        mainDisplay = "HEADLESS-1";
        displays = [
          {
            name = "HEADLESS-1";
            mode = "1216x2688@60Hz";
            x = 0;
            y = 0;
            touch = null;
          }
        ];
      };
    };
}
