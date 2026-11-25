# Match the port's defconfig + fragment, not nixpkgs' generic server config.
# The EFI stub takes the external NixOS initrd; do not run mkinitramfs.sh.
{ pkgs, inputs }:
let
  src = inputs.nx809j-linux;
  llvm = pkgs.llvmPackages;
  configfile = llvm.stdenv.mkDerivation {
    name = "nx809j-kernel-config";
    inherit src;
    nativeBuildInputs = with pkgs; [
      bison
      flex
      bc
      llvm.lld
      llvm.llvm
    ];
    buildPhase = ''
      patchShebangs scripts
      make ARCH=arm64 LLVM=1 defconfig
      scripts/kconfig/merge_config.sh -m .config ${inputs.nx809j-port}/configs/nx809j.config
      # The fleet firewall uses reverse-path filtering with iptables.
      scripts/config -m NFT_COMPAT -m IP_NF_MATCH_RPFILTER -m IP6_NF_MATCH_RPFILTER
      make ARCH=arm64 LLVM=1 olddefconfig
      grep -qx CONFIG_IP_NF_MATCH_RPFILTER=m .config
      grep -qx CONFIG_IP6_NF_MATCH_RPFILTER=m .config
      grep -qx CONFIG_EFI_STUB=y .config
      grep -qx CONFIG_MODULES=y .config
    '';
    installPhase = "cp .config $out";
  };
in
(pkgs.linuxManualConfig {
  inherit src configfile;
  features = {
    efiBootStub = true;
    netfilterRPFilter = true;
  };
  config.CONFIG_MODULES = "y";
  version = "7.3.0";
  modDirVersion = "7.3.0-next-20261022-nx809j";
  stdenv = llvm.stdenv;
  extraMakeFlags = [
    "LLVM=1"
    "HOSTCC=${llvm.clang}/bin/clang"
    "HOSTCXX=${llvm.clang}/bin/clang++"
    "HOSTLD=${llvm.lld}/bin/ld.lld"
    "HOSTLDFLAGS=-Wl,-rpath,${pkgs.lib.makeLibraryPath [ pkgs.openssl pkgs.elfutils pkgs.zlib ]}"
    "LD=${llvm.lld}/bin/ld.lld"
  ];
}).overrideAttrs
  (old: {
    nativeBuildInputs = old.nativeBuildInputs ++ [
      llvm.lld
      llvm.llvm
    ];
  })
