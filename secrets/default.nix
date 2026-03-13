let
  fuji = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKdNZb6qncSHcALFxtzADCDSEt+03VLhRQmNSn+rHa2";
  yari = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvcfPMD8iAvxwWA8Epfk95CvszjzsQSDpetkjgdPZPh";
  rakku = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCzfq63PfBDlmLY3JhfA/F6P+PDzgqhJUo0loDFm64niqjulExRp3kP9OIae0LZJ/Su4xN1vEOgPBEgJRvvUB7X1QGrndOqdJ1u71bcUYAl40vJXOX3OiprZ+rSX5pAhIYWWqun5o2VRGBQeeV1Ieco5kyMxLcfKNhqg9dqGViV/f0+vuBPgy8oqOeEu2/26XBqLNAjHO75XkjwGsEtJfbnaJq5qKIEPbLY3uLguIaWetPWY1gvNNOfawwZEH8NoSD1c/1cL8AoP9nhtiIbWh73MJboM9H/IJ/2z578R1yZgED0gF0cXMVztz6CO+1NoskZjau6QJPf4mYel9mpFXIOxIcaBha7+eB1dtYm5Wvsz//B4YR3N/BhyXYJzckAA7Ais5/ZC0EoI3CQCFyi1waY4LyCTrn1ayFgWqYou0HdEM1gYIfeVuopbhbTtIF0lIQgL6sjPoMWEW0+ThQ4Uja3twGCTSXv4s8mQuh+pkd0B+2bfiTeXy/HUJQK37ZQWRnUw1XXkti2Y3BH5Ru47Bq8NfYLnauDOV78mf0VgCnfpHm5Nihl/X7rX+AZoU5O8N/60vCxqqTA2vKUPLt3e9wjpZ5zLVl4WuxgfjJ1aF+Og0RQ2sV93dZkC94+HzI5zfJLpR3RtVdK6XGmz64iu8nXL1wlrp+adXi5m6LVKU2ASQ==";
  kita = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJ2wxCqg5o1BBCoyqTF5lmh5WZSFbYauHMgKYBscJ2gbtgWmpaJgs+6Sgr2jhApMwprs86Zngf7WinxPLuE6j7Tb/W+gTiqWxPnd6nD63H/HQfyC3f0YutJlwlMI7qupC0WQpw/iBerpJ138JX6i//Ww3ENJzV8o/7zHkm9brv5Mu+58pFCl5HLlk+vvZEievJqt/TxfJQbvzVa55boJQ1M+kWN7gzC14MwenUkZECqfd42PhXiecjRPnaMrP5uiBT4xfFarDLQaaem5pgV5kzcU7bCj8sS71T3BHRMPLVVtSyZbpfp5R8UytMfGFFzlFK+uHc9qelznGSKEFp12w6oBOv0q5cJ59kgtUfahqFGWUdq8ysUw47KoX2LLLVMUK5nnD2+l0BGQuNPuG1iq6VWoMsYm4MQtm5hNHDFdmUArjdO38KQFMqCYirhfeItPUxkEngeh6hz0lZCRegyOz3i/1KQl/DlYbgzOvT4Sl7pJ8W85soegdHtH1vSDhaIork/DqeLomqsDkkuLFwXUffMilPUTZo/gh4VqIZxItjdRXqlHd/HIorNoWSbg6KzFjgYzA1MgaKwfc9H4UbR4C5SI9tDsGigaidBJdlHT7G+Vz7qqnr/7mHhuj/XAQ29KkeDMBmHuQwTxAlA0s3oNidkXNTmyqHUnt71ZHSFuEIaw==";
  yuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFi4kQTMhafaVN7BrLiS7P7gS0v/VPAXeMWX0geqB0bj root@yuki";
  aso = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4uSTAyOR0h8hrNltBDAQ9UnszVBZ9IVzyoA19r3uet root@nixos";
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjTWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";

  fujiKeys = [fuji simonwjackson];
  yariKeys = [yari simonwjackson];
  fujiYariKeys = [fuji yari simonwjackson];
  rakkuKeys = [rakku simonwjackson];
  kitaKeys = [kita simonwjackson];
  yukiKeys = [yuki simonwjackson];
  asoKeys = [aso simonwjackson];
  allKeys = [fuji yari rakku kita yuki aso simonwjackson];
in {
  # Shared machine Tailscale auth key
  "secrets/tailscale-authkey.age".publicKeys = allKeys;
  "secrets/pandora-password.age".publicKeys = fujiKeys ++ rakkuKeys ++ kitaKeys;
  "secrets/groq-env.age".publicKeys = fujiKeys;
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

  # Rakku secrets
  "secrets/tailscale-ephemeral.age".publicKeys = rakkuKeys ++ kitaKeys;
  "secrets/zwave-js-secrets.age".publicKeys = rakkuKeys;

  # Yuki secrets
  "secrets/hosts/yuki/simonwjackson-password-hash.age".publicKeys = yukiKeys;
  "secrets/hosts/yuki/syncthing-cert.age".publicKeys = yukiKeys;
  "secrets/hosts/yuki/syncthing-key.age".publicKeys = yukiKeys;

  # Fuji syncthing secrets
  "secrets/hosts/fuji/syncthing-cert.age".publicKeys = fujiKeys;
  "secrets/hosts/fuji/syncthing-key.age".publicKeys = fujiKeys;
}
