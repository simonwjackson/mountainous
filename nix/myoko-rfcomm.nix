{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "myoko-rfcomm";
  inherit (kernel) version;

  src = ../modules/glymur/rfcomm;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  # Only the socket half of RFCOMM is built. HFP needs the RFCOMM socket for
  # its AT command channel. The serial port emulation in tty.c needs
  # CONFIG_BT_RFCOMM_TTY, and rfcomm.h already stubs its two entry points out
  # when that symbol is absent.
  postPatch = ''
    cp ${kernel.src}/net/bluetooth/rfcomm/core.c .
    cp ${kernel.src}/net/bluetooth/rfcomm/sock.c .
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
    description = "Bluetooth RFCOMM module from the matching Myoko kernel source";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
