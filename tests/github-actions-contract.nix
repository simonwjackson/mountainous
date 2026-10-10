# Evaluate the production feature against the pinned upstream runner module.
{
  enabled,
  disabled,
  lib,
}:
let
  runner = enabled.services.github-runners.forgerie;
  service = enabled.systemd.services.github-runner-forgerie;
  policy = service.serviceConfig;
  slice = enabled.systemd.slices.github-actions.sliceConfig;
  identity = "github-runner-forgerie";
  scratch = "/srv/github-actions/tmp/forgerie";
in
assert !disabled.mountainous.features.github-actions.enable;
assert !(disabled.systemd.services ? github-runner-forgerie);
assert !(disabled.users.users ? github-runner-forgerie);
assert runner.enable && runner.count == 1 && runner.ephemeral;
assert runner.url == "https://github.com/forgerie";
assert runner.runnerGroup == "unzen-forgerie-manual";
assert runner.noDefaultLabels && runner.extraLabels == [ "unzen-forgerie" ];
assert runner.tokenFile == null && runner.githubApp != null;
assert runner.workDir == "/srv/github-actions/work/forgerie";
assert runner.extraEnvironment.TMPDIR == scratch;
assert runner.user == identity && runner.group == identity;
assert enabled.users.users.${identity}.isSystemUser;
assert !(builtins.elem "wheel" enabled.users.users.${identity}.extraGroups);
assert !(builtins.elem identity enabled.nix.settings.trusted-users);
assert !policy.DynamicUser;
assert policy.NoNewPrivileges && policy.ProtectHome && policy.ProtectKernelTunables;
assert policy.ProtectSystem == "strict";
assert policy.Slice == "github-actions.slice";
assert slice.CPUQuota == "400%" && slice.MemoryMax == "16G";
assert slice.MemoryHigh == "12G" && slice.TasksMax == 2048;
assert builtins.elem "/srv/github-actions/work/forgerie" policy.BindPaths;
assert builtins.all
  (parent: builtins.elem "d ${parent} 0750 root ${identity} -" enabled.systemd.tmpfiles.rules)
  [
    "/srv/github-actions"
    "/srv/github-actions/work"
    "/srv/github-actions/tmp"
  ];
assert builtins.elem "${scratch}:/tmp" policy.BindPaths;
assert builtins.elem "${scratch}:/var/tmp" policy.BindPaths;
assert builtins.elem "-/nix/var/nix/daemon-socket" policy.InaccessiblePaths;
assert builtins.elem "-/run/secrets/github-actions-forgerie-app-key" policy.InaccessiblePaths;
assert builtins.elem "100.64.0.0/10" policy.IPAddressDeny;
assert lib.hasInfix "github-actions-prepare" (builtins.elemAt policy.ExecStartPre 0);
assert lib.hasInfix "github-actions-preflight.py" (builtins.elemAt policy.ExecStartPre 1);
assert lib.hasInfix "unconfigure-github-app" (builtins.elemAt policy.ExecStartPre 2);
assert policy.Restart == "always";
assert policy.RestartSec == "30s" && policy.TimeoutStartSec == "180s";
assert service.unitConfig.StartLimitIntervalSec == 0;
assert enabled.environment.etc."github-actions/ready".mode == "0700";
assert builtins.any (
  package: lib.getName package == "nodejs" && lib.hasPrefix "24." package.version
) runner.extraPackages;
{
  status = "pass";
  disabledByDefault = true;
  jobs = 1;
  cpuQuota = slice.CPUQuota;
  memoryMax = slice.MemoryMax;
  rootAppKeyHidden = true;
  hostNixDaemonHidden = true;
  diskBackedScratch = true;
  readableNonWritableAncestors = true;
  githubPolicyCheckedBeforeRegistration = true;
  startupFailureRetries = true;
  retryDelaySeconds = 30;
  startupTimeoutSeconds = 180;
  onDemandReadiness = true;
  evidence = "Nix evaluation only; not a live GitHub registration or lifecycle test";
}
