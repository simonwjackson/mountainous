# Auto-generated from directory conventions.
# All secrets are encrypted for every host + the user key so that any
# machine can decrypt any secret.  Host-scoping is handled at the NixOS
# module level (only the matching host *declares* a host-specific secret).
let
  fuji = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKdNZb6qncSHcALFxtzADCDSEt+03VLhRQmNSn+rHa2";
  yari = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIvcfPMD8iAvxwWA8Epfk95CvszjzsQSDpetkjgdPZPh";
  rakku = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC8OeJfG7CpfHg7yrCOz8N/hwn7tyxYmmM3EGNDF8lwc3YXGnE7nm8kS/5csuaG4LQNbS5bXGSE30X2X78xGvgob/l0r2LvjHKMmEuDTQlXZdaVP8raBqI8/5DNwkpR91eqpV+2xXdr/LeDzLS/y/jLgKfhmNCyiXiKSsd67VykZuEEurMWVvZpEKS1dtHZliDULUPpG6qi7fu5qPTKm4msh88XCz44A8CMUrEUMkFadGyQ4SyyMZxnpRidn4NqSVbTosJmR96mXFvblB6tvZut25qnHlcmrtKknMecfRkyTgHoDegpDMUMjKd0LMhdXQ+IDwkVSdhs0F0vlnatxZyivb5j+OonZ/E6LcaOKtsww2Lo8/4p8plkewOvJ/yUBjSRgLDcz9M67O6rYdTVPZ0wdeiut4Ah3Vrh93FVv/88siDUyL3Zyiwm9p2bloU5rxmSIM+x4Kr0BAnZvoQrHdnbzHh/3M2rOmbL7EUVu2hJaN7UVAIZageGrElbxUlObMXWU0GqeWggUNehiMPvrv6DFYPcTPhSETwGbHdf8Dsk0QJQLlHccWhRPW2FV7TCxhH7oaFNEBSxtIqsq/HyC5pS2LdZslhP31EWlyyT/uXgpUe4eSmeAUI5NYoHEeV7KEW6OBSpbvk02ns0vf5lx4KSOpQL143IoZ2FC+MWRBfdyQ==";
  yuki = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFi4kQTMhafaVN7BrLiS7P7gS0v/VPAXeMWX0geqB0bj root@yuki";
  aso = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB4uSTAyOR0h8hrNltBDAQ9UnszVBZ9IVzyoA19r3uet root@nixos";
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";

  allKeys = [fuji yari rakku yuki aso simonwjackson];

  # ── Auto-discovery ───────────────────────────────────────────────────
  # Recursively find every .age file under ./  (skipping archived/ and keys/).
  scanDir = dir: prefix:
    builtins.foldl' (
      acc: name: let
        type = (builtins.readDir dir).${name};
        path = dir + "/${name}";
        rel =
          if prefix == ""
          then name
          else "${prefix}/${name}";
      in
        if type == "directory" && name != "archived" && name != "keys"
        then acc ++ (scanDir path rel)
        else if type == "regular" && builtins.match ".*\\.age$" name != null
        then acc ++ [rel]
        else acc
    ) [] (builtins.attrNames (builtins.readDir dir));

  allAgeFiles = scanDir ./. "";
in
  builtins.listToAttrs (map (rel: {
      name = "secrets/${rel}";
      value.publicKeys = allKeys;
    })
    allAgeFiles)
