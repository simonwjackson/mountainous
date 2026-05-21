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
  aka = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDK3vVIlXjPk1LPa2ANJ9dsUD0lKv3iDV0zjnoByuDZ1qUzRVNOE3J3MfNQVDRko/OLHZjQn2FmtGzgTb+cgoT8RDc9/Dg1Y8ZzFhivwYVcFCr4D1FfH+KzwGBPyKZWlH5buPw3repAGEUWhtTad+HP9tlATzTFU1dAi33GahfNSQptXgIns/mpz2xOk7vv+hhNGTaKinRJ8VgqZfLFut/unXzV1501WDsY87fhTyg5B1KxNM1wKwSAxt/NHEKr/LauONW0KpSDFON+PA8873wcxVVj44+n+i2QbbqVWaMUkkm3rZws78TzhCItKY05XmxYHmijxX+rVKXf/vD+w74Vs3tw8ceENxIwvNg8tuytX9sUnXI8VXsPM7/ol0NXqY6NoG18YeHfoVsxMWsUY1Uov1kyoD0G4xbOej/RmIzsDG7NYU6UiRUiHph5sJdof1UhB2+aOn/o8JlEy28rpLgoqoVdsUAnwNEvH27NotUIeMDZyAojJVjEDUlsIJ9tzp3u42G27cCaXErDS8I5cnJYUgyJmBPzVmMKrRFNw2US6WZ96FrjKulkl/gkprh+Hqlmx0PN7JdBES5RhWIgF5Rc/Rlq19L/l+Z+VzLHgAELv0ksoLMGz1LGQlyJxts3VjrndUN7TsxjshLfOAPjZ6rEKdqX7BvRjB2Osi7++BdQJQ== root@aka";
  zao = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCcC+/QxsQko0Ywm5SMDzv+X5HPI6qV9/BFRP9hm7GdwtDFVbL6r+R57Tjlp6tyJ0m7bJg3J5BK3Y1fcLrYR5Uamm95BO0zZI64qMG9EwKrhrKwSz3u+Lvkhw1XIYI0PgAtXaKCHHPOOzAt/mHM095NWj7zIXuzpdoQVQxMsAn+lgRhawavgMX8z0qARG38SaasI3y2BcsT7wrTKqZ132CwlDYQTi3O6uDIvYyut0S5Cd9dx7rBKM65hx9VQ5dNlceuD97qP+UfoPfN9/yZATphNXVGZoQgzQFSao8i99diQGe6UuOX8Ug3nFuHXRZiDHFZ6CYncmq34Z6lOWP5ToFTP6YTsDXSO0r6bdudSHoFol5BF10Hsb2Ce/e9y+yZyC7MiEwJsLa2j1H+c75dT+vDci5VWIiB/3bapHW0JGz0WfnSg3YH6HeNV0UZJlkXQoyzX/YkInhZCGece1b7YCxOdiJDIvqQrGK/blt+oa7eKBoi+9QvPkkGKVmtaBJAy7KalPXAqR4iU99O7zj4SbdOAo1OI08jS9mNpOS5cXvqQcMH1OE4pRn6Ignpj25I3pHCz3rGNHFy+OFr73o49xwKoknz7hEGrfTAB4mZDVAp/s0K5xC0ruyPL4ceuha2yQcEefVLK4AKMVvFH+g7Gl1oLs4XS824r258PvPLZdX1FQ== zao host key";
  kita = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCVCueckjpRUG7e1YSEIQ1BE1QpqjlkHyvngDTAhkKy5XBpAQOvDz1lDqAa60Fr9r7is7Z12TCsm2XJ3hHfGeVVAgq0IFfW2XnrdKv6hm3ZlqZz9vFXT9Vu7UECBNpaJqjPzEgjgT7ah3dOP3DZrD7rFzHt0Lo9K/tgC9yS2bgrwRL2Y7/VV473LS9Uitv9mrEeWFRN94WBUt0/SsWyT7Pk4QSaOOpKPKaPBu0JolFvQJGiZNz3yoYDShe8PLRGCTsqpvKzVR+SL6dWBWjc1SO2B+YoAkH6rBgvQvAzUYWjr4/0NS0PhY+NdQr+AKG2+Gcgp/TwDl10chbPpxUd0twxpKIdZf5rIV+OiUHrbnzuF/a3iqxlvgFDZUhWDQMJVnUcc75/I7ZOtS8vgFVlAjO9xUlIbYugA8KqYPTB8IdpsBAQPw7PyuUipe1FZUudPQCJZSPGmh6hqF2b5aZBYQegCjpOtp4TWEPdYjC918JKMB7Rm0bio0ob822LNIaFWtMwXlmsUJV50BBZTJwAHjC7WjEx+VcyYCMGzzxZmuekX1ixXCNbbOrI3m6iCvieezC+3QYNlm2KAwrYGWJkK1a4NYJz++Spthcr5tMJ16SDshjhuy0nIlAuqVP56ufrMsXy/ZoQqraBBzifTXKHkyjmEGZfgVXK0sD+yIj+HK8fLw== host-key-kita";
  ibuki = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCJvlECbzTVUNNsqtJheQ9h64DDWATkf5BhB/MkmOh8qh3+FYh6yJXWicVHYtF+KFJFJdLOQBIm+OA6nu7/cAvIVMt4ajmjSPuXl16s78hTjm1smbfr6ZgoGizT6YS+kHWeomStKDIL/B1n1gJ5kTZeh1QIKxrz0JJuIiV26WrGggIvC503M7Sh2c3uvnL4Cl050I1Ty5XeMIajcYQtOk8i7AJYTEfTEhJWCSYes0/+BavZZCdRF21KCv0BdsMfBWJgDuiZ/LyhxzO2kkbdX8N+g4Nux8CIvjUSRhXH+0zNlMHZGgivaEVL06JlIvxDZtCCY6kzWtFXoVzrg0Qh72KoZfglk/6FFTnplsqq//m6uiGUKF2oUnbgD3H1zECggnoRNJTNPVargIc1YnT5yBiKRbSAnMURcKp1VFDQh1j4DOqdelEhIPnK4gme+ZIBH3Dk1ZJvimIVxvuRDlpBpWqEO+I3BZZVaB3SB860wZ+qzkK7xT6piGFiACcI5TRsh+hqTMQmEmGJMnfbBQVWtAdhNhV5kheYo3OSO2XX5KHklM2tUDKOpTV39upGlyKSICEw3Fvi510B1lukQ/ch/fAb0ydvXDw9CqHfzFJ47WJDMMGxyyQCNbSwIdvtBSMNNOSELcue/jBgnZLruvqvV32xk3qUHG82UHvprMmRSVd7Sw==";
  sobo = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDRl5/BWbHgenk+itCnq71FmZ6/Ogx6aCRDzITnTrTVCH8BObhxd1W8xKFiDjNt0fXfAUIxPioVT3GN9z5SltK9jGsS/9l/a3IVLqrws1vhNY93FlEOTdQgGl10Ien5HlpJallcld3qgy76PJIII8sytc/YI0MKNwoe/knFWX91E2T/IZHozA4fPhHvoA51+wDod0elze/ZVq3dJzsIYsZ+JZ5ewCSxUkANHpMwpbQO7JBZxJY3SWpzlmByPYQqfP8c6PRGFkxkNYYwe8531kaKXgViY9gBdfDTdA9m3UVhWhX7zu9AF45jBA03T6mt1sq2ysE37ZCjcG/ZEcb+F3TdzBDuS3+vR+8+d650YyUYvEjepa25LwfgiUeOYeOq0T8v40V81PKRcRkuL4VbtGHn6qBPuGP6pyd3IQQiln5qnCzNB/gXcy1E8w0Xk59lZ+PgQ97EZxMELVAflS6Cm5NClX5vyWELVNkklW50toRdBnIpPa9z7PdDIIUP8/kDWNdTtG0g0OuXAHc8NrExOuJ847xjj4WhpCVUQxpoOxZ4+zC82vqvd9ysDQ68ohN/sotJriCxL3Zskn+gfL65Tj80TReXxVWduhun+QaWIwmmNjnYvsHd1qJW3nkP2IszliT1PwGmpJOAN5eCv1gpfpSnd14kbZHH/xji/+2ZC9Iyuw==";
  simonwjackson = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ==";

  allKeys = [fuji yari rakku yuki aso aka zao kita ibuki sobo simonwjackson];

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
