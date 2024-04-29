{
  rootPath,
  config,
  ...
}: {
  # age.secrets."user-simonwjackson-taskserver-private.key".file = rootPath + /secrets/user-simonwjackson-taskserver-private.key.age;
  # age.secrets."user-simonwjackson-taskserver-public.cert".file = rootPath + /secrets/user-simonwjackson-taskserver-public.cert.age;
  # age.secrets."user-simonwjackson-taskserver-ca.cert".file = rootPath + /secrets/user-simonwjackson-taskserver-ca.cert.age;

  programs.taskwarrior = {
    enable = true;
    config = {
      confirmation = false;
      taskd = {
        # certificate = config.age.secrets."user-simonwjackson-taskserver-public.cert".path;
        # key = config.age.secrets."user-simonwjackson-taskserver-private.key".path;
        # ca = config.age.secrets."user-simonwjackson-taskserver-ca.cert".path;
        server = "yari:53589";
        credentials = "mountainous/simonwjackson/430e9d17-bc5e-4534-9c37-c1dcab337dbe";
      };
    };
  };

  home.file.".local/share/task/hooks/on-exit-sync.sh" = {
    # TODO: move this to an external file
    text = ''
      #!/bin/sh
      # This hooks script syncs task warrior to the configured task server.
      # The on-exit event is triggered once, after all processing is complete.

      # Make sure hooks are enabled


      # Count the number of tasks modified
      n=0
      while read modified_task
      do
          n=$(($n + 1))
      done

      if (($n > 0)); then
          task sync >> ~/sync_hook.log > /dev/null 2>&1 &
      fi

      exit 0
    '';
    executable = true;
  };

  services.taskwarrior-sync = {
    enable = true;
    frequency = "*:0/5";
  };
}
