{
  config,
  age,
  inputs,
  pkgs,
  ...
}: {
  age.secrets.aria2-rpc-secret.file = ../../../../../secrets/aria2-rpc-secret.age;
  programs.aria2 = {
    enable = true;
    settings = {
      dht-listen-port = 60000;
      dir = config.xdg.userDirs.download;
      enable-rpc = true;
      ftp-pasv = true;
      listen-port = 60000;
      max-concurrent-downloads = 5;
      max-connection-per-server = 1;
      max-upload-limit = "50K";
      rpc-listen-port = 6800;
      on-download-complete = "notify-send 'Download complete' 'Download of %s completed'";
      on-download-error = "notify-send 'Download error' 'Download of %s failed'";
      on-download-pause = "notify-send 'Download paused' 'Download of %s paused'";
      on-download-start = "notify-send 'Download started' 'Download of %s started'";
      on-bt-download-complete = "notify-send 'Download complete' 'Download of %s completed'";
      on-bt-download-error = "notify-send 'Download error' 'Download of %s failed'";
      on-bt-download-pause = "notify-send 'Download paused' 'Download of %s paused'";
      on-bt-download-start = "notify-send 'Download started' 'Download of %s started'";
      # BitTorrent
      seed-ratio = 0.0000001;
    };
  };

  systemd.user.services.aria2 = {
    Unit = {
      Description = "aria2 background service";
    };
    Service = {
      # HACK
      #Environment = "XDG_RUNTIME_DIR=/run/user/1000";
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.aria2}/bin/aria2c --rpc-secret=$(${pkgs.coreutils}/bin/cat /run/user/1000/agenix/aria2-rpc-secret)'";
      Restart = "always";
    };
    Install = {
      WantedBy = ["network-online.target" "default.target"];
    };
  };
}
