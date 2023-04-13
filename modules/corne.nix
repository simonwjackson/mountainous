{ pkgs, ... }: {
  services.udev.packages = [
    (pkgs.writeTextFile {
      name = "corne";
      text = ''
        ACTION=="add", SUBSYSTEM=="input", ATTRS{id/product}=="615e", ATTRS{id/vendor}=="1d50", ENV{DISPLAY}=":0", ENV{XAUTHORITY}="/home/simonwjackson/.Xauthority", RUN+="${pkgs.stdenv.shell} -c '${pkgs.xorg.xinput}/bin/xinput float 7'"
        ACTION=="remove", SUBSYSTEM=="input", ATTRS{id/product}=="615e", ATTRS{id/vendor}=="1d50", ENV{DISPLAY}=":0", ENV{XAUTHORITY}="/home/simonwjackson/.Xauthority", RUN+="${pkgs.stdenv.shell} -c '${pkgs.xorg.xinput}/bin/xinput reattach 7 3'"
      '';
      destination = "/etc/udev/rules.d/99-corne.rules";
    })
  ];
}
