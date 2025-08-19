# brightness-sync

A tool to synchronize brightness between internal laptop displays and external monitors on Linux.

## Features

- Synchronize brightness across all connected displays
- Support for both internal displays (via sysfs/backlight) and external monitors (via DDC/CI)
- Manual and automatic synchronization modes
- Simple command-line interface

## Installation

### In NixOS Configuration

Add to your system packages:

```nix
environment.systemPackages = with pkgs; [
  brightness-sync
];
```

### Manual Build

```bash
nix build .#brightness-sync
```

## Usage

### Basic Commands

```bash
# Get current brightness of all displays
brightness-sync get

# Set all displays to 50% brightness
brightness-sync set 50

# Increase brightness by 10%
brightness-sync up 10

# Decrease brightness by 5% (default step)
brightness-sync down

# Sync external display to match internal
brightness-sync sync

# Watch for changes and auto-sync
brightness-sync watch
```

### Hyprland Integration

Add keybindings to your Hyprland configuration:

```nix
# In your hyprland configuration
bind = SUPER, F5, exec, brightness-sync down 10
bind = SUPER, F6, exec, brightness-sync up 10
bind = SUPER SHIFT, F5, exec, brightness-sync set 20
bind = SUPER SHIFT, F6, exec, brightness-sync set 80
```

### Auto-sync on Boot

To automatically sync displays on boot, add a systemd service:

```nix
systemd.user.services.brightness-sync = {
  description = "Synchronize display brightness";
  wantedBy = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "oneshot";
    ExecStart = "${pkgs.brightness-sync}/bin/brightness-sync sync";
  };
};
```

### Continuous Synchronization

For continuous synchronization (useful when adjusting brightness via laptop keys):

```nix
systemd.user.services.brightness-sync-watch = {
  description = "Monitor and sync display brightness";
  wantedBy = [ "graphical-session.target" ];
  serviceConfig = {
    Type = "simple";
    ExecStart = "${pkgs.brightness-sync}/bin/brightness-sync watch";
    Restart = "on-failure";
  };
};
```

## Requirements

- **ddcutil**: For controlling external monitors via DDC/CI
- **brightnessctl** or **brillo** (optional): For better internal display control
- **sudo privileges**: Required for DDC/CI commands (can be configured with sudoers)

## Troubleshooting

### External monitor not detected

1. Ensure your monitor supports DDC/CI
2. Check with: `sudo ddcutil detect`
3. Some monitors require DDC/CI to be enabled in their OSD menu

### Permission issues

Add your user to the i2c group:
```bash
sudo usermod -a -G i2c $USER
```

Or add a sudoers rule for passwordless ddcutil:
```bash
echo "$USER ALL=(ALL) NOPASSWD: /usr/bin/ddcutil" | sudo tee /etc/sudoers.d/ddcutil
```

## Limitations

- Only supports one external monitor (uses display ID 1)
- Requires DDC/CI support on external monitors
- Some monitors may have slower response times for DDC commands