{
  lib,
  stdenv,
  kernel,
  kernelModuleMakeFlags,
}:
stdenv.mkDerivation {
  pname = "myoko-uhid";
  inherit (kernel) version;

  src = ../modules/glymur/uhid;

  nativeBuildInputs = kernel.moduleBuildDependencies;

  postPatch = ''
    cp ${kernel.src}/drivers/hid/uhid.c .
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
    description = "UHID module from the matching Myoko kernel source";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
