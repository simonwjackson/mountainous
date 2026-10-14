# One tailnet URL for "System One" decision models: typed yes/no, choice and
# score answers with probabilities, from any provider, through LiteLLM.
#
# LiteLLM serves POST /v1/decisions (OpenAI format) and POST /v1/systemone
# (System One format) from v1.104.2 on the 1.104.x line and v1.105.0-rc.3 on.
# It translates between them, so every model below answers on both routes.
# https://docs.litellm.ai/docs/decisions
#
# nixpkgs carries LiteLLM 1.80 (Rakku's pin) and 1.100 (unstable), so this
# runs the vendor image. A digest is immutable; the tag is only a label.
#
# No database: the master key is the only API key. Virtual keys, budgets and
# stored spend logs need Postgres (DATABASE_URL) and are not set up.
{ config, self, ... }:
let
  hosts = config.nixos.hosts;
in
{
  # The gateway must stay tailnet-only and pinned on every host that runs it.
  perSystem =
    { pkgs, lib, ... }:
    let
      problems = lib.concatLists (
        lib.mapAttrsToList (
          name: host:
          let
            c = self.nixosConfigurations.${name}.config;
            litellm = c.virtualisation.oci-containers.containers.litellm;
            persisted = map (
              entry: if builtins.isString entry then entry else entry.directory
            ) c.environment.persistence."/tundra/permafrost".directories;
            want = ok: msg: lib.optional (!ok) "${name}: ${msg}";
          in
          lib.optionals (builtins.elem "decision-gateway" host.layers) (
            want (
              builtins.match ".*@sha256:[0-9a-f]{64}" litellm.image != null
            ) "LiteLLM image is not pinned by digest"
            ++ want (lib.elem "--network=host" litellm.extraOptions) "LiteLLM is not on the host network"
            ++ want (
              lib.elem "127.0.0.1" litellm.cmd && !(lib.elem "0.0.0.0" litellm.cmd)
            ) "LiteLLM listens beyond loopback"
            ++ want (litellm.ports == [ ]) "LiteLLM publishes a port"
            ++ want (!(lib.elem 4000 c.networking.firewall.allowedTCPPorts)) "port 4000 is open"
            ++ want (c.mountainous.tailnetNames ? decide) "no tailnet name"
            ++ want (lib.hasInfix "-oauth-secret-file" c.systemd.services.tsnet-proxy-decide.serviceConfig.ExecStart) "the tailnet name does not join with OAuth"
            ++ want (lib.all (d: lib.elem d persisted) [
              "/var/lib/containers"
              "/var/lib/tsnet-proxy-decide"
            ]) "gateway state is not persisted"
          )
        ) hosts
      );
    in
    {
      checks.decision-gateway =
        if problems == [ ] then
          pkgs.runCommand "decision-gateway" { } "touch $out"
        else
          throw "decision gateway:\n  ${lib.concatStringsSep "\n  " problems}";
    };

  nixos.modules.decision-gateway =
    { config, pkgs, ... }:
    let
      port = 4000;
      # Provider keys come from the litellm-env secret. A missing key makes
      # only that model fail, with an authentication error from the provider.
      settings = {
        model_list = [
          {
            model_name = "jev";
            litellm_params = {
              model = "typesafe/jev-latest";
              api_key = "os.environ/TYPESAFE_API_KEY";
            };
          }
          {
            # Needs an OpenAI API key with API billing. A ChatGPT sign-in
            # token does not work on /v1/decisions.
            model_name = "luna";
            litellm_params = {
              model = "openai/gpt-6-luna";
              api_key = "os.environ/OPENAI_API_KEY";
            };
          }
          {
            # "fast" asks Jev first, then Luna. Confidence scales differ by
            # model, so callers read the response "model" field.
            model_name = "fast";
            litellm_params = {
              model = "typesafe/jev-latest";
              api_key = "os.environ/TYPESAFE_API_KEY";
            };
          }
        ];
        router_settings.fallbacks = [ { fast = [ "luna" ]; } ];
        general_settings.master_key = "os.environ/LITELLM_MASTER_KEY";
      };
      configFile = (pkgs.formats.yaml { }).generate "litellm.yaml" settings;
    in
    {
      # litellm-env is a dotenv block: LITELLM_MASTER_KEY, and optionally
      # TYPESAFE_API_KEY and OPENAI_API_KEY. One block lets a provider key be
      # absent without failing activation.
      sops.secrets.litellm-env = {
        sopsFile = ../secrets/hosts/${config.networking.hostName}.yaml;
        mode = "0400";
        restartUnits = [ "podman-litellm.service" ];
      };

      virtualisation.oci-containers.backend = "podman";
      virtualisation.oci-containers.containers.litellm = {
        # v1.105.1
        image = "ghcr.io/berriai/litellm@sha256:b7b9e2c306343721802253d0dd9436b9634a2eb4e14da7c7cf06c5c7b7530802";
        cmd = [
          "--config"
          "/etc/litellm/config.yaml"
          "--host"
          "127.0.0.1"
          "--port"
          (toString port)
        ];
        environment.LITELLM_TELEMETRY = "False";
        environmentFiles = [ config.sops.secrets.litellm-env.path ];
        volumes = [ "${configFile}:/etc/litellm/config.yaml:ro" ];
        # Host network on loopback only. The tailnet name below is the only
        # way in; the LAN interface is trusted on this host, so 0.0.0.0 would
        # expose it.
        extraOptions = [
          "--network=host"
          "--cap-drop=all"
          "--security-opt=no-new-privileges"
        ];
      };
      systemd.services.podman-litellm = {
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        # Never pull the image into the tmpfs root. A switch that adds the
        # bind mount does not start it on its own.
        unitConfig.RequiresMountsFor = [ "/var/lib/containers" ];
      };

      # Root is tmpfs. Keep the image on disk so a reboot does not pull it
      # again into memory.
      environment.persistence."/tundra/permafrost".directories = [
        {
          directory = "/var/lib/containers";
          mode = "0700";
        }
      ];

      mountainous.tailnetNames.decide = {
        description = "Decision gateway tailnet proxy";
        backend = "http://127.0.0.1:${toString port}";
        after = [ "podman-litellm.service" ];
      };
    };
}
