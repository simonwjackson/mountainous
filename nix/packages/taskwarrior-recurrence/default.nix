{
  lib,
  python3Packages,
  inputs,
  ...
}:
python3Packages.buildPythonApplication {
  pname = "taskwarrior-recurrence";
  version = "unstable";

  src = inputs.taskwarrior-recurrence;

  pyproject = true;
  build-system = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    tasklib
  ];

  # Don't run tests as this is a simple hook package
  doCheck = false;

  postInstall = ''
    # Create directory for hooks and copy the Python files
    mkdir -p $out/share/taskwarrior-hooks

    # Copy hook files from the installed package
    cp $out/${python3Packages.python.sitePackages}/taskwarrior_recurrence/*.py \
      $out/share/taskwarrior-hooks/

    # Make them executable
    chmod +x $out/share/taskwarrior-hooks/*.py
  '';

  meta = with lib; {
    description = "Chained recurrence hooks for Taskwarrior";
    longDescription = ''
      Taskwarrior hooks that implement chained recurrence instead of periodic
      recurrence. With chained recurrence, the next task only appears after
      you complete the current one, preventing pileup of overdue tasks.
      Perfect for habits and routines where the next occurrence should be
      relative to when you actually completed the last one.
    '';
    homepage = "https://github.com/lyz-code/taskwarrior_recurrence";
    license = licenses.gpl3;
    platforms = platforms.linux;
    maintainers = [];
  };
}
