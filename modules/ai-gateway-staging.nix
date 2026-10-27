# Keep the validated staging identity and grants separate from production.
{ inputs, self, ... }:
let
  instance = {
    name = "ai-gateway-staging";
    tailnetName = "ai-staging";
    secretPrefix = "ai-staging";
    listenPort = 8420;
    egressPort = 8421;
  };
in
{
  perSystem = import ../lib/ai-gateway-check.nix (
    instance
    // {
      inherit self;
      testMode = "staging";
    }
  );
  nixos.modules.ai-gateway-staging =
    { config, lib, ... }:
    {
      imports = [
        (import ../lib/ai-gateway-instance.nix (
          instance
          // {
            inherit inputs;
            loginKeeperSecret = "ai-staging-login-keeper";
            usageSecret = "ai-staging-usage";
            description = "AI gateway staging front door (no production cutover)";
            egressDescription = "Staging-only provider hostname allowlisting CONNECT proxy";
            tailnetDescription = "AI staging tailnet proxy";
            gatewayKeys = geminiImageModels: [
              {
                name = "ai-staging-test-a";
                secret = "ai-staging-test-a";
                credential = "test-a";
                models = [
                  "claude-opus-5-5"
                  "gpt-6.1-sol"
                  "gpt-image-2"
                  "gemini-3.8-flash-high"
                  "deepseek-v4.1-flash"
                  "jev"
                  "solar"
                  "fast"
                  "eleven_multilingual_v2"
                  "grok-tts"
                ]
                ++ geminiImageModels;
                dialects = [
                  "codex"
                  "responses"
                  "chat_completions"
                  "messages"
                  "speech"
                  "images"
                  "systemone"
                  "models"
                  "quota"
                ];
                monthly_cap_usd = 2.0;
                requests_per_minute = 10;
              }
              {
                name = "ai-staging-test-b";
                secret = "ai-staging-test-b";
                credential = "test-b";
                models = [ "jev" ];
                dialects = [ "systemone" ];
                monthly_cap_usd = 0.01;
                requests_per_minute = 10;
              }
            ];
          }
        ))
      ];
      config = lib.mkIf config.mountainous.features.ai-gateway-staging.enable {
        sops.secrets.ai-staging-login-keeper = {
          sopsFile = ../secrets/fleet.yaml;
          key = "pi-cliproxyapi-api-key";
          mode = "0400";
          restartUnits = [ "ai-gateway-staging.service" ];
        };
      };
    };
}
