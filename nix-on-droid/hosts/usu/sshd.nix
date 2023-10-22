let
  sshdTmpDirectory = "${config.user.home}/sshd-tmp";
  sshdDirectory = "${config.user.home}/sshd";
  pubKey = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC/PwyhdbVKd6jcG55m/1sUgEf0x3LUeS9H4EK5vk9PKhvDsjOQOISyR1LBmmXUFamkpFo2c84ZgPMj33qaPfOF0VfmF79vdAIDdDt5bmsTU6IbT7tGJ1ocpHDqhqbDO3693RdbTt1jTQN/eo3AKOfnrMouwBZPbPVqoWEhrLUvUTuTq7VQ+lUqWkvGs4D6D8UeIlG9VVgVhad3gCohYsjGdzgOUy0V4c8t3BuHrIE6//+6YVJ9VWK/ImSWmN8it5RIREDgdSYujs1Uod+ovr8AvaGFlFC9GuYMsj7xDYL1TgaWhy5ojk6JcuuF0cmoqffoW/apYdYM6Vxi5Xe6aJUhVyguZDovWcqRdPv2q0xtZn6xvNkoElEkrb6t0CAbGKf++H4h8/v5MsMt9wUPJAJBa24v0MlU8mXTUwhFLP5YQ/A8AAb5Y3ty/6DaOlvvTzt5Om2SMrZ1XaL1II35dFNZ/Os3zRpqdWq9SnpisRA+Bpf0bPUjdi8D8rRJn8g3zO5EsldBlZg82PiJcRHANbydTSK6Jzw7A8S5gMyPoH80Pq5MbQPvPpevTfOKy14NyTYPHGj0j5y7EQP7yb6w70LtqdRLRLQSTCdF0qTjVWw/qdt9MXkS7cdQe4yBADmjwozwPuxAs/jNpxELcVPEWBK6DcAIFD0vv3Xaw7reXpXFTQ=="
    port = 8022;
in
{
  build.activation.sshd = ''
    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
    $DRY_RUN_CMD echo "${pubKey}" > "${config.user.home}/.ssh/authorized_keys"

    if [[ ! -d "${sshdDirectory}" ]]; then
      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshdTmpDirectory}"
      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshdTmpDirectory}"

      $VERBOSE_ECHO "Generating host keys..."
      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "${sshdTmpDirectory}/ssh_host_rsa_key" -N ""

      $VERBOSE_ECHO "Writing sshd_config..."
      $DRY_RUN_CMD echo -e "HostKey ${sshdDirectory}/ssh_host_rsa_key\nPort ${toString port}\n" > "${sshdTmpDirectory}/sshd_config"

      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshdTmpDirectory}" "${sshdDirectory}"
    fi
  '';

  environment.packages = [
    (pkgs.writeScriptBin "sshd-start" ''
      #!${pkgs.runtimeShell}

      echo "Starting sshd in non-daemonized way on port ${toString port}"
      ${pkgs.openssh}/bin/sshd -f "${sshdDirectory}/sshd_config" -D
    '')
  ];
}
