{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkIf;

  cfg = config.mountainous.taskwarrior;
in {
  options.mountainous.taskwarrior = {
    enable = mkEnableOption "Taskwarrior with chained recurrence hooks";
  };

  config = mkIf cfg.enable {
    # Install the recurrence hook package
    home.packages = with pkgs; [
      taskwarrior-recurrence
    ];

    # Configure taskwarrior with required UDAs for chained recurrence
    programs.taskwarrior = {
      enable = true;
      package = pkgs.taskwarrior3;
      dataLocation = "${config.xdg.dataHome}/task";
      config = {
        # Disable default recurrence behavior
        recurrence = "no";

        # Configure recurring task report filter
        "report.recurring.filter" = "status:recurring";

        # Define User Defined Attributes (UDAs) for chained recurrence
        "uda.rtype.label" = "Recur.Type";
        "uda.rtype.type" = "string";
        "uda.rtype.values" = "chained,periodic";

        "uda.r.label" = "TwRecurrence";
        "uda.r.type" = "string";

        "uda.rparent.label" = "Parent task";
        "uda.rparent.type" = "string";

        "uda.rwait.label" = "Recur.Wait";
        "uda.rwait.type" = "date";

        "uda.rscheduled.label" = "Recur.Scheduled";
        "uda.rscheduled.type" = "date";

        "uda.rlastinstance.label" = "Last child task";
        "uda.rlastinstance.type" = "string";
      };
    };

    # Install recurrence hooks
    home.activation.installTaskwarriorHooks = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p "${config.xdg.dataHome}/task/hooks"

      # Symlink the hook scripts with the correct names
      # Note: Files in nix store are already executable, no need to chmod
      run ln -sf ${pkgs.taskwarrior-recurrence}/share/taskwarrior-hooks/on_add.py \
        "${config.xdg.dataHome}/task/hooks/on-add-fix-recurrence.py"
      run ln -sf ${pkgs.taskwarrior-recurrence}/share/taskwarrior-hooks/on_exit.py \
        "${config.xdg.dataHome}/task/hooks/on-exit-fix-recurrence.py"
    '';
  };
}
