# Real QEMU boot with the NixOS Plymouth/initrd integration. Preview both
# installed scripts through Plymouth's real X11 renderer in the guest. The
# guest's Xvfb is not the host's GPU, seat, display or audio.
{ pkgs, themes }:
{
  name = "desktop-boot";
  nodes.machine = { ... }: {
    boot.plymouth = {
      enable = true;
      theme = "mountainous-platinum";
      themePackages = [ themes ];
      showDelay = 0;
      extraConfig = "DeviceTimeout=0.1";
    };
    virtualisation.memorySize = 1024;
    environment.systemPackages = [
      pkgs.xorg.xorgserver
      pkgs.imagemagick
      pkgs.xorg.xauth
      pkgs.xdotool
    ];
    system.stateVersion = "25.05";
  };
  testScript = ''
    from datetime import timedelta
    start_all()
    machine.wait_for_unit("multi-user.target")
    machine.succeed("test -e /etc/plymouth/themes/mountainous-platinum/boot.png")
    machine.succeed("test -e /etc/plymouth/themes/mountainous-win98/shutdown.png")
    machine.succeed("Xvfb :1 -screen 0 800x600x24 -ac >/tmp/xvfb.log 2>&1 &")
    machine.wait_until_succeeds("DISPLAY=:1 ${pkgs.xorg.xdpyinfo}/bin/xdpyinfo >/dev/null")
    for theme in ["platinum", "win98"]:
        machine.succeed("rm /etc/plymouth/plymouthd.conf")
        machine.succeed(f"printf '[Daemon]\\nTheme=mountainous-{theme}\\nShowDelay=0\\nDeviceTimeout=0.1\\n' >/etc/plymouth/plymouthd.conf")
        for mode in ["boot", "shutdown"]:
            machine.succeed(f"DISPLAY=:1 plymouthd --pid-file=/run/plymouth/pid --debug --debug-file=/tmp/{theme}-{mode}.log --mode={mode} --kernel-command-line='splash console=tty1 plymouth.ignore-serial-consoles' --tty=/dev/tty1 --graphical-boot --ignore-serial-consoles </dev/null >/tmp/daemon.log 2>&1")
            machine.wait_until_succeeds("plymouth --ping")
            import time
            started = time.monotonic()
            machine.succeed("plymouth show-splash")
            elapsed = time.monotonic() - started
            print(f"{theme} {mode} show-splash roundtrip: {elapsed * 1000:.1f} ms")
            assert elapsed < 0.2, "splash must not block boot for 200 ms"
            machine.sleep(1)
            machine.succeed(f"DISPLAY=:1 import -window root /tmp/{theme}-{mode}.png")
            machine.copy_from_machine(f"/tmp/{theme}-{mode}.png")
            if mode == "boot":
                # Each preview restarts the daemon; restart the watch agent
                # too. A real boot keeps a single daemon and agent.
                machine.succeed("systemctl restart systemd-ask-password-plymouth.service")
                machine.succeed("systemd-ask-password --no-tty --timeout=15 'Unlock test disk' >/tmp/answer 2>/tmp/ask-error &")
                machine.sleep(1)
                machine.succeed("DISPLAY=:1 xdotool type test-only")
                machine.sleep(1)
                machine.succeed(f"DISPLAY=:1 import -window root /tmp/{theme}-password.png")
                machine.copy_from_machine(f"/tmp/{theme}-password.png")
                machine.succeed("DISPLAY=:1 xdotool key Return")
                machine.wait_until_succeeds("grep -qx test-only /tmp/answer", timeout=timedelta(seconds=10))
            machine.succeed("plymouth quit")
            machine.copy_from_machine(f"/tmp/{theme}-{mode}.log")
            machine.fail(f"grep -Ei '(parse error|script error|execution error)' /tmp/{theme}-{mode}.log")
    machine.succeed("pkill Xvfb")
  '';
}
