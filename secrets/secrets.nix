let
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";
  users = [simonwjackson];

  asahi = builtins.readFile ../systems/x86_64-linux/asahi/ssh_host_rsa_key.pub;
  fiji = builtins.readFile ../systems/x86_64-linux/fiji/ssh_host_rsa_key.pub;
  haku = builtins.readFile ../systems/x86_64-linux/haku/ssh_host_rsa_key.pub;
  kita = builtins.readFile ../systems/x86_64-linux/kita/ssh_host_rsa_key.pub;
  naka = builtins.readFile ../systems/aarch64-linux/naka/ssh_host_rsa_key.pub;
  piney = builtins.readFile ../systems/aarch64-linux/piney/ssh_host_rsa_key.pub;
  rakku = builtins.readFile ../systems/x86_64-linux/rakku/ssh_host_rsa_key.pub;
  unzen = builtins.readFile ../systems/x86_64-linux/unzen/ssh_host_rsa_key.pub;
  ushiro = builtins.readFile ../systems/aarch64-darwin/ushiro/ssh_host_rsa_key.pub;
  yari = builtins.readFile ../systems/x86_64-linux/yari/ssh_host_rsa_key.pub;
  zao = builtins.readFile ../systems/x86_64-linux/zao/ssh_host_rsa_key.pub;

  systems = [
    asahi
    fiji
    haku
    kita
    naka
    piney
    rakku
    unzen
    ushiro
    yari
    zao
  ];
in {
  "user-simonwjackson.age".publicKeys = users ++ systems;
  "user-simonwjackson-pin.age".publicKeys = users ++ systems;
  "user-simonwjackson-openai-api-key.age".publicKeys = users ++ systems;
  "user-simonwjackson-instapaper.age".publicKeys = users ++ systems;
  "user-simonwjackson-gmail.age".publicKeys = users ++ systems;
  "user-simonwjackson-taskserver-ca.cert.age".publicKeys = users ++ systems;
  "user-simonwjackson-taskserver-private.key.age".publicKeys = users ++ systems;
  "user-simonwjackson-taskserver-public.cert.age".publicKeys = users ++ systems;
  "user-simonwjackson-github-token.age".publicKeys = users ++ systems;
  "user-simonwjackson-github-token-nix.age".publicKeys = users ++ systems;
  "user-simonwjackson-email.age".publicKeys = users ++ systems;
  "user-simonwjackson-anthropic.age".publicKeys = users ++ systems;

  "aria2-rpc-secret.age".publicKeys = users ++ systems;
  "tailscale.age".publicKeys = users ++ systems;
  "tailscale_env.age".publicKeys = users ++ systems;
  "tandoor_env.age".publicKeys = users ++ systems;
  "paperless_ngx_env.age".publicKeys = users ++ systems;
  "atuin_key.age".publicKeys = users ++ systems;
  "atuin_session.age".publicKeys = users ++ systems;
  "game-collection-sync.age".publicKeys = users ++ systems;

  "gluetun_env.age".publicKeys = users ++ systems;

  "zao-syncthing-key.age".publicKeys = users ++ [zao];
  "zao-syncthing-cert.age".publicKeys = users ++ [zao];

  "unzen-syncthing-key.age".publicKeys = users ++ [unzen];
  "unzen-syncthing-cert.age".publicKeys = users ++ [unzen];

  "naka-syncthing-key.age".publicKeys = users ++ [naka];
  "naka-syncthing-cert.age".publicKeys = users ++ [naka];

  "fiji-syncthing-key.age".publicKeys = users ++ [fiji];
  "fiji-syncthing-cert.age".publicKeys = users ++ [fiji];

  "kita-syncthing-key.age".publicKeys = users ++ [kita];
  "kita-syncthing-cert.age".publicKeys = users ++ [kita];

  "matrix-shared-secret.age".publicKeys = users ++ [yari];
  "ntfy-htpasswd.age".publicKeys = users ++ [yari];
}
