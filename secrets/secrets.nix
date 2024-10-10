let
  main_user = builtins.readFile ../rsa.pub;
  users = [main_user];

  aka = builtins.readFile ../systems/x86_64-linux/aka/ssh_host_rsa_key.pub;
  asahi = builtins.readFile ../systems/x86_64-linux/asahi/ssh_host_rsa_key.pub;
  fiji = builtins.readFile ../systems/x86_64-linux/fiji/ssh_host_rsa_key.pub;
  haku = builtins.readFile ../systems/x86_64-linux/haku/ssh_host_rsa_key.pub;
  kita = builtins.readFile ../systems/x86_64-linux/kita/ssh_host_rsa_key.pub;
  naka = builtins.readFile ../systems/aarch64-linux/naka/ssh_host_rsa_key.pub;
  nyu = builtins.readFile ../systems/x86_64-linux/nyu/ssh_host_rsa_key.pub;
  rakku = builtins.readFile ../systems/x86_64-linux/rakku/ssh_host_rsa_key.pub;
  unzen = builtins.readFile ../systems/x86_64-linux/unzen/ssh_host_rsa_key.pub;
  # ushiro = builtins.readFile ../systems/aarch64-darwin/ushiro/ssh_host_rsa_key.pub;
  yari = builtins.readFile ../systems/x86_64-linux/yari/ssh_host_rsa_key.pub;
  zao = builtins.readFile ../systems/x86_64-linux/zao/ssh_host_rsa_key.pub;

  systems = [
    aka
    asahi
    fiji
    haku
    kita
    naka
    nyu
    rakku
    unzen
    # ushiro
    yari
    zao
  ];
in {
  "user-simonwjackson.age".publicKeys = users ++ systems;
  "user-simonwjackson-pin.age".publicKeys = users ++ systems;
  "user-simonwjackson-openai-api-key.age".publicKeys = users ++ systems;
  "deepseek-api-key.age".publicKeys = users ++ systems;
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

  "aka-syncthing-key.age".publicKeys = users ++ [aka];
  "aka-syncthing-cert.age".publicKeys = users ++ [aka];

  "fiji-syncthing-key.age".publicKeys = users ++ [fiji];
  "fiji-syncthing-cert.age".publicKeys = users ++ [fiji];

  "kita-syncthing-key.age".publicKeys = users ++ [kita];
  "kita-syncthing-cert.age".publicKeys = users ++ [kita];

  "matrix-shared-secret.age".publicKeys = users ++ [yari];
  "ntfy-htpasswd.age".publicKeys = users ++ [yari];
}
