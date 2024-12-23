let
  tsukuba = builtins.readFile ../keys/hosts/x86_64-linux_tsukuba_ssh_host_rsa_key.pub;
  main_user = builtins.readFile ../keys/users/rsa.pub;
  users = [main_user];

  aka = builtins.readFile ../keys/hosts/x86_64-linux_aka_ssh_host_rsa_key.pub;
  asahi = builtins.readFile ../keys/hosts/x86_64-linux_asahi_ssh_host_rsa_key.pub;
  cho = builtins.readFile ../keys/hosts/x86_64-linux_cho_ssh_host_rsa_key.pub;
  fuji = builtins.readFile ../keys/hosts/x86_64-linux_fuji_ssh_host_rsa_key.pub;
  haku = builtins.readFile ../keys/hosts/x86_64-linux_haku_ssh_host_rsa_key.pub;
  hira = builtins.readFile ../keys/hosts/x86_64-linux_hira_ssh_host_rsa_key.pub;
  kita = builtins.readFile ../keys/hosts/x86_64-linux_kita_ssh_host_rsa_key.pub;
  naka = builtins.readFile ../keys/hosts/aarch64-linux_naka_ssh_host_rsa_key.pub;
  nyu = builtins.readFile ../keys/hosts/x86_64-linux_nyu_ssh_host_rsa_key.pub;
  rakku = builtins.readFile ../keys/hosts/x86_64-linux_rakku_ssh_host_rsa_key.pub;
  unzen = builtins.readFile ../keys/hosts/x86_64-linux_unzen_ssh_host_rsa_key.pub;
  usu = builtins.readFile ../keys/hosts/x86_64-linux_usu_ssh_host_rsa_key.pub;
  yari = builtins.readFile ../keys/hosts/x86_64-linux_yari_ssh_host_rsa_key.pub;
  zao = builtins.readFile ../keys/hosts/x86_64-linux_zao_ssh_host_rsa_key.pub;

  systems = [
    tsukuba
    aka
    asahi
    cho
    fuji
    haku
    hira
    kita
    naka
    nyu
    rakku
    unzen
    usu
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
  "slskd_env.age".publicKeys = users ++ systems;
  "aria2-rpc-secret.age".publicKeys = users ++ systems;
  "tandoor_env.age".publicKeys = users ++ systems;
  "paperless_ngx_env.age".publicKeys = users ++ systems;
  "atuin_key.age".publicKeys = users ++ systems;
  "atuin_session.age".publicKeys = users ++ systems;
  "game-collection-sync.age".publicKeys = users ++ systems;
  "searx-env.age".publicKeys = users ++ systems;

  #########
  # Usenet
  #########

  "sabnzbd-api-key.age".publicKeys = users ++ systems;
  "sabnzbd-nzb-key.age".publicKeys = users ++ systems;

  "newsdemon-user.age".publicKeys = users ++ systems;
  "newsdemon-pass.age".publicKeys = users ++ systems;

  #########
  # VPN
  #########

  "tailscale-ephemeral.age".publicKeys = users ++ systems;
  "tailscale.age".publicKeys = users ++ systems;
  "tailscale_env.age".publicKeys = users ++ systems;

  "proton-0-usenet.age".publicKeys = users ++ systems;
  "proton-0-soulseek.age".publicKeys = users ++ systems;
  "proton-0-index.age".publicKeys = users ++ systems;
  "proton-0-torrents.age".publicKeys = users ++ systems;
  "proton-0-downloads.age".publicKeys = users ++ systems;

  "proton-1.age".publicKeys = users ++ systems;
  "proton-2.age".publicKeys = users ++ systems;

  "fastestvpn.age".publicKeys = users ++ systems;

  #########
  # Syncthing
  #########

  "zao-syncthing-key.age".publicKeys = users ++ [zao];
  "zao-syncthing-cert.age".publicKeys = users ++ [zao];

  "sobo-syncthing-key.age".publicKeys = users ++ [usu];
  "sobo-syncthing-cert.age".publicKeys = users ++ [usu];

  "usu-syncthing-key.age".publicKeys = users ++ [usu];
  "usu-syncthing-cert.age".publicKeys = users ++ [usu];

  "bandi-syncthing-key.age".publicKeys = users ++ systems;
  "bandi-syncthing-cert.age".publicKeys = users ++ systems;

  "haku-syncthing-key.age".publicKeys = users ++ systems;
  "haku-syncthing-cert.age".publicKeys = users ++ systems;

  "unzen-syncthing-key.age".publicKeys = users ++ [unzen];
  "unzen-syncthing-cert.age".publicKeys = users ++ [unzen];

  "naka-syncthing-key.age".publicKeys = users ++ [naka];
  "naka-syncthing-cert.age".publicKeys = users ++ [naka];

  "aka-syncthing-key.age".publicKeys = users ++ [aka];
  "aka-syncthing-cert.age".publicKeys = users ++ [aka];

  "fuji-syncthing-key.age".publicKeys = users ++ [fuji];
  "fuji-syncthing-cert.age".publicKeys = users ++ [fuji];

  "kita-syncthing-key.age".publicKeys = users ++ [kita];
  "kita-syncthing-cert.age".publicKeys = users ++ [kita];

  "matrix-shared-secret.age".publicKeys = users ++ [yari];
  "ntfy-htpasswd.age".publicKeys = users ++ [yari];

  #######
  # Services
  #######

  "kavita.age".publicKeys = users ++ systems;

  ########
  # Heidi
  ########

  "heidi-tailscale.age".publicKeys = users ++ systems;

  ########
  # wifi
  ########

  "wifi-vrackie.age".publicKeys = users ++ systems;

  ########
  # bluetooth
  ########

  "bluetooth-fuji-sony-ote.age".publicKeys = users ++ systems;
}
