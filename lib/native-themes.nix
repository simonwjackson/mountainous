# One build-time source for all native toolkit derivatives. No Apple-derived
# artwork lives in this repository; every asset comes from a locked input.
{ pkgs, inputs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "desktop-native-themes";
  version = "1";
  dontUnpack = true;
  nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.pillow ])) ];
  buildPhase = ''
    runHook preBuild
    python3 ${../scripts/generate-native-themes.py} \
      --out "$out" --mac ${inputs.platinum-gtk-src} \
      --chicago ${inputs.chicago95-src} --kvantum ${inputs.platinum-kvantum-src}
    runHook postBuild
  '';
  dontInstall = true;
  meta = {
    description = "Platinum and Windows 98 native desktop appearances";
    # Mac-OS-9 and the stable Kvantum fork include GPLv3 texts. Chicago95's
    # README declares GPL-3.0+/MIT; its theme code is kept under GPL-3.0+.
    license = with pkgs.lib.licenses; [
      gpl3Only
      gpl3Plus
      mit
    ];
    platforms = pkgs.lib.platforms.linux;
  };
}
