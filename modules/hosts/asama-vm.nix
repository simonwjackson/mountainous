{ inputs, ... }:
{
  nixos.hosts.asama-vm = {
    enrolled = false;
    system = "x86_64-linux";
    nixpkgs = inputs.korri.inputs.nixpkgs;
    layers = [
      "desktop-shared"
      "phone"
      "denial"
      "korri"
    ];
    module =
      {
        config,
        lib,
        pkgs,
        modulesPath,
        ...
      }:
      let
        compositor = pkgs.callPackage "${inputs.denial}/nix/compositor.nix" {
          src = pkgs.applyPatches {
            name = "source";
            src = inputs.denial;
            patches = [ ../asama-vm/0001-kms-mark-implicit-gbm-allocations-implicit.patch ];
          };
        };
      in
      {
        imports = [ (modulesPath + "/virtualisation/qemu-vm.nix") ];
        boot.kernelPackages = pkgs.linuxPackages_7_2;
        boot.kernelParams = [
          "video=Virtual-1:1216x2688"
          "quiet"
        ];
        systemd.services.usb-gadget.enable = false;
        # No fleet decryption key or tailnet identity in the guest. Rakku is
        # reached through Myoko's NAT; login uses the operator's SSH key.
        system.activationScripts.setupSecrets.text = lib.mkForce "";
        system.activationScripts.setupSecretsForUsers.text = lib.mkForce "";
        users.users.simon.hashedPasswordFile = lib.mkForce null;
        users.users.root.hashedPasswordFile = lib.mkForce null;
        systemd.services.tailscale-join.enable = false;
        programs.denial.package = pkgs.denial.overrideAttrs (old: {
          postInstall = (old.postInstall or "") + ''
            install -Dm755 ${compositor}/bin/deniald $out/bin/deniald
          '';
        });
        environment.sessionVariables.DENIAL_VM_IMPLICIT_SCANOUT = "1";
        environment.etc."denial/outputs.conf".text = ''
          Virtual-1=0,0
          mode=Virtual-1,1216,2688,60000
          scale=Virtual-1,2
          system_bar=hidden
          maximize_padding=0
        '';
        systemd.user.services.tarn = {
          description = "Tarn window on Rakku";
          partOf = [ "denial-session.target" ];
          environment.TARN_SERVER = "ws://100.88.212.117:4790";
          serviceConfig.ExecStart = lib.getExe inputs.tarn.packages.x86_64-linux.default;
        };
        virtualisation = {
          cores = 6;
          memorySize = 4096;
          diskSize = 16384;
          forwardPorts = [
            {
              from = "host";
              host.address = "127.0.0.1";
              host.port = 2223;
              guest.port = 22;
            }
          ];
          qemu.package = pkgs.symlinkJoin {
            name = "qemu-with-vulkan-loader";
            paths = [ pkgs.qemu_kvm ];
            nativeBuildInputs = [ pkgs.makeWrapper ];
            postBuild = ''
              for b in $out/bin/qemu-system-*; do
                wrapProgram "$b" --prefix LD_LIBRARY_PATH : ${pkgs.vulkan-loader}/lib
              done
            '';
          };
          qemu.options = [
            "-vga none"
            "-object memory-backend-memfd,id=mem1,size=${toString config.virtualisation.memorySize}M,share=on"
            "-machine memory-backend=mem1"
            "-device virtio-vga-gl,edid=on,xres=1216,yres=2688,blob=true,hostmem=4G,venus=true"
            "-display gtk,gl=on,zoom-to-fit=on"
            "-device virtio-multitouch-pci"
            "-device virtio-tablet-pci"
            "-device virtio-keyboard-pci"
          ];
        };
      };
  };
}
