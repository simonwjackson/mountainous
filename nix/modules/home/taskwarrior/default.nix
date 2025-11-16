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
    # Install taskwarrior and the recurrence hook package
    home.packages = with pkgs; [
      taskwarrior3
      taskwarrior-recurrence
    ];

    # Configure taskwarrior with required UDAs for chained recurrence
    programs.taskwarrior = {
      enable = true;
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
      run mkdir -p "$HOME/.task/hooks"

      # Symlink the hook scripts with the correct names
      run ln -sf ${pkgs.taskwarrior-recurrence}/share/taskwarrior-hooks/on_add.py \
        "$HOME/.task/hooks/on-add-fix-recurrence.py"
      run ln -sf ${pkgs.taskwarrior-recurrence}/share/taskwarrior-hooks/on_exit.py \
        "$HOME/.task/hooks/on-exit-fix-recurrence.py"

      # Ensure hooks are executable
      run chmod +x "$HOME/.task/hooks"/*.py
    '';
  };
}
