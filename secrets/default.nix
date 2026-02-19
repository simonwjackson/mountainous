let
  fuji = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKdNZb6qncSHcALFxtzADCDSEt+03VLhRQmNSn+rHa2";
  rakku = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC..."; # TODO: extract from rakku's host key
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";

  fujiKeys = [ fuji simonwjackson ];
  rakkuKeys = [ rakku simonwjackson ];
  allKeys = [ fuji rakku simonwjackson ];
in {
  # Fuji secrets
  "secrets/tailscale-authkey.age".publicKeys = fujiKeys;
  "secrets/pandora-password.age".publicKeys = fujiKeys;
  "secrets/groq-env.age".publicKeys = fujiKeys;
  "secrets/fastest-vpn.age".publicKeys = fujiKeys;
  "secrets/openclaw-env.age".publicKeys = fujiKeys;
  "secrets/outlook-calendar-url.age".publicKeys = fujiKeys;
  "secrets/ebay-api-env.age".publicKeys = fujiKeys;
  "secrets/ebay-refresh-token.age".publicKeys = fujiKeys;
  "secrets/nutrition-api-keys.age".publicKeys = fujiKeys;
  "secrets/omi-api-key.age".publicKeys = fujiKeys;
  "secrets/invidious-token.age".publicKeys = fujiKeys;
  "secrets/google-oauth-client.age".publicKeys = fujiKeys;
  "secrets/oura-api-token.age".publicKeys = fujiKeys;
  "secrets/withings-client-id.age".publicKeys = fujiKeys;
  "secrets/withings-client-secret.age".publicKeys = fujiKeys;
  "secrets/ketomojo-client-id.age".publicKeys = fujiKeys;
  "secrets/ketomojo-client-secret.age".publicKeys = fujiKeys;
  "secrets/borg-passphrase.age".publicKeys = fujiKeys;
  "secrets/kroger-client-id.age".publicKeys = fujiKeys;
  "secrets/kroger-client-secret.age".publicKeys = fujiKeys;
  "secrets/rclone-conf.age".publicKeys = fujiKeys;
  "secrets/gogcli-credentials.age".publicKeys = fujiKeys;
  "secrets/gogcli-keyring.age".publicKeys = fujiKeys;
  "secrets/hf-token.age".publicKeys = fujiKeys;
  "secrets/anthropic-api-key.age".publicKeys = fujiKeys;
  "secrets/telegram-bot-token.age".publicKeys = fujiKeys;

  # Rakku secrets
  "secrets/tailscale-ephemeral.age".publicKeys = rakkuKeys;
  "secrets/zwave-js-secrets.age".publicKeys = rakkuKeys;
}
