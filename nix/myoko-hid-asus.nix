{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "myoko-hid-asus";
  inherit (kernel) version;

  src = ../modules/glymur/hid-asus;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    cp ${kernel.src}/drivers/hid/hid-asus.c .
    cp ${kernel.src}/drivers/hid/hid-ids.h .
    patch -p1 < 0001-zenbook-a16-backlight.patch
  '';

  makeFlags = kernelModuleMakeFlags;

  buildPhase = ''
    runHook preBuild
    make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" M="$PWD" modules ''${makeFlagsArray[@]}
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    make -C "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build" M="$PWD" modules_install INSTALL_MOD_PATH="$out" ''${makeFlagsArray[@]}
    runHook postInstall
  '';

  meta = {
    description = "ASUS HID keyboard module from the matching Myoko kernel source";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
