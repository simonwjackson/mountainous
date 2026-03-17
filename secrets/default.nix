let
  fuji = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKdNZb6qncSHcALFxtzADCDSEt+03VLhRQmNSn+rHa2";
  yari = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvcfPMD8iAvxwWA8Epfk95CvszjzsQSDpetkjgdPZPh";
  rakku = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8OeJfG7CpfHg7yrCOz8N/hwn7tyxYmmM3EGNDF8lwc3YXGnE7nm8kS/5csuaG4LQNbS5bXGSE30X2X78xGvgob/l0r2LvjHKMmEuDTQlXZdaVP8raBqI8/5DNwkpR91eqpV+2xXdr/LeDzLS/y/jLgKfhmNCyiXiKSsd67VykZuEEurMWVvZpEKS1dtHZliDULUPpG6qi7fu5qPTKm4msh88XCz44A8CMUrEUMkFadGyQ4SyyMZxnpRidn4NqSVbTosJmR96mXFvblB6tvZut25qnHlcmrtKknMecfRkyTgHoDegpDMUMjKd0LMhdXQ+IDwkVSdhs0F0vlnatxZyivb5j+OonZ/E6LcaOKtsww2Lo8/4p8plkewOvJ/yUBjSRgLDcz9M67O6rYdTVPZ0wdeiut4Ah3Vrh93FVv/88siDUyL3Zyiwm9p2bloU5rxmSIM+x4Kr0BAnZvoQrHdnbzHh/3M2rOmbL7EUVu2hJaN7UVAIZageGrElbxUlObMXWU0GqeWggUNehiMPvrv6DFYPcTPhSETwGbHdf8Dsk0QJQLlHccWhRPW2FV7TCxhH7oaFNEBSxtIqsq/HyC5pS2LdZslhP31EWlyyT/uXgpUe4eSmeAUI5NYoHEeV7KEW6OBSpbvk02ns0vf5lx4KSOpQL143IoZ2FC+MWRBfdyQ==";
  yuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFi4kQTMhafaVN7BrLiS7P7gS0v/VPAXeMWX0geqB0bj root@yuki";
  aso = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4uSTAyOR0h8hrNltBDAQ9UnszVBZ9IVzyoA19r3uet root@nixos";
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";

  fujiKeys = [fuji simonwjackson];
  yariKeys = [yari simonwjackson];
  fujiYariKeys = [fuji yari simonwjackson];
  rakkuKeys = [rakku simonwjackson];
  rakkuYariKeys = [rakku yari simonwjackson];
  yukiKeys = [yuki simonwjackson];
  asoKeys = [aso simonwjackson];
  allKeys = [fuji yari rakku yuki aso simonwjackson];
in {
  # Shared machine Tailscale auth key
  "secrets/tailscale-authkey.age".publicKeys = allKeys;
  "secrets/groq-env.age".publicKeys = fujiKeys ++ yukiKeys;
  "secrets/fastest-vpn.age".publicKeys = fujiYariKeys;
  "secrets/openclaw-env.age".publicKeys = fujiYariKeys;
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
  "secrets/ado-refresh-token.age".publicKeys = fujiKeys;

  # Search API keys (all machines)
  "secrets/serper-api-key.age".publicKeys = allKeys;
  "secrets/brave-api-key.age".publicKeys = allKeys;

  # OCI secrets (all machines)
  "secrets/oci-config.age".publicKeys = allKeys;
  "secrets/oci-api-key.age".publicKeys = allKeys;
  "secrets/oci-yari-key.age".publicKeys = allKeys;

  # Rakku / Yari shared service secrets
  "secrets/tailscale-ephemeral.age".publicKeys = rakkuYariKeys;
  "secrets/system/usenet/newsdemon-user.age".publicKeys = yariKeys;
  "secrets/system/usenet/newsdemon-pass.age".publicKeys = yariKeys;
  "secrets/system/usenet/nzbgeek-api.age".publicKeys = yariKeys;
  "secrets/system/usenet/nzbget-pass.age".publicKeys = yariKeys;
  "secrets/system/radarr/radarr-pass.age".publicKeys = yariKeys;
  "secrets/system/jellyfin/jellyfin-pass.age".publicKeys = yariKeys;

  # Rakku secrets
  "secrets/zwave-js-secrets.age".publicKeys = rakkuKeys;

  # Yuki secrets
  "secrets/hosts/yuki/simonwjackson-password-hash.age".publicKeys = yukiKeys;
  "secrets/hosts/yuki/syncthing-cert.age".publicKeys = yukiKeys;
  "secrets/hosts/yuki/syncthing-key.age".publicKeys = yukiKeys;

  # Fuji syncthing secrets
  "secrets/hosts/fuji/syncthing-cert.age".publicKeys = fujiKeys;
  "secrets/hosts/fuji/syncthing-key.age".publicKeys = fujiKeys;

  # Yari syncthing secrets
  "secrets/hosts/yari/syncthing-cert.age".publicKeys = yariKeys;
  "secrets/hosts/yari/syncthing-key.age".publicKeys = yariKeys;
}
