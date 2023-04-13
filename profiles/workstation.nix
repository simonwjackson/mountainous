{ pkgs, ... }:

{
  imports = [
    ../modules/syncthing.nix
  ];

  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true; # rtkit is optional but recommended

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    jack.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    # jack.enable = true;
  };

  environment.variables.BROWSER = "firefox";

  programs.mosh.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    bluez
    bluez-tools
    xsettingsd
    gsettings-desktop-schemas
    kitty # INFO: `sxhkd` can't find kitty without adding here as well
    tailscale # make the tailscale command usable to users
  ];

  # enable the tailscale service
  services.tailscale.enable = true;

  systemd.services.tailscale-autoconnect = {
    description = "Automatic connection to Tailscale";

    # make sure tailscale is running before trying to connect to tailscale
    after = [ "network-pre.target" "tailscale.service" ];
    wants = [ "network-pre.target" "tailscale.service" ];
    wantedBy = [ "multi-user.target" ];

    # set this service as a oneshot job
    serviceConfig.Type = "oneshot";

    # have the job run this shell script
    script = with pkgs; ''
      # wait for tailscaled to settle
      sleep 2

      # check if we are already authenticated to tailscale
      status="$(${tailscale}/bin/tailscale status -json | ${jq}/bin/jq -r .BackendState)"
      if [ $status = "Running" ]; then # if so, then do nothing
        exit 0
      fi

      # otherwise authenticate with tailscale
      ${tailscale}/bin/tailscale up -authkey '' + builtins.getEnv "TAILSCALE_AUTHKEY";
  };
}

