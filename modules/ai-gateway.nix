# Production is additive. Client cutovers are separate commits.
{ inputs, self, ... }:
let
  instance = {
    name = "ai-gateway";
    tailnetName = "ai";
    secretPrefix = "ai-gateway";
    listenPort = 8430;
    egressPort = 8431;
  };
in
{
  perSystem = import ../lib/ai-gateway-check.nix (
    instance
    // {
      inherit self;
      testMode = "production";
    }
  );
  nixos.modules.ai-gateway =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      imports = [
        (import ../lib/ai-gateway-instance.nix (
          instance
          // {
            inherit inputs;
            # Root's LoadCredential can read Pi's existing root/simon-readable file.
            # This is the same fleet key as staging's alias; do not alter its ownership.
            loginKeeperSecret = "pi-cliproxyapi-api-key";
            usageSecret = "ai-gateway-usage";
            description = "AI gateway production front door";
            egressDescription = "AI gateway provider hostname allowlisting CONNECT proxy";
            tailnetDescription = "AI gateway tailnet proxy";
            elevenlabsSpeech = {
              model = {
                id = "eleven_flash_v2_5";
                provider = "elevenlabs";
                name = "ElevenLabs Flash v2.5";
              };
              # ElevenLabs API Flash/Turbo, $0.04 per 1K characters, every plan; https://elevenlabs.io/pricing/api, checked 2026-10-27
              price.audio_per_million_characters = 40.0;
            };
            gatewayKeys = _: [
              {
                name = "assistant@rakku";
                secret = "ai-gateway-key-assistant-rakku";
                credential = "assistant";
                dialects = [
                  "codex"
                  "models"
                  "responses"
                ];
                models = [
                  "claude-opus-5-5"
                  "gpt-6.1-sol"
                  "gemini-3.8-flash-high"
                  "gpt-5.6-luna"
                ];
                monthly_cap_usd = 0;
                requests_per_minute = 600;
              }
              {
                name = "voice@zao";
                secret = "ai-gateway-key-voice-zao";
                credential = "voice-zao";
                dialects = [ "speech" ];
                models = [ "eleven_flash_v2_5" ];
                monthly_cap_usd = 5;
                requests_per_minute = 120;
              }
            ];
          }
        ))
      ];
      config = lib.mkIf config.mountainous.features.ai-gateway.enable {
        mountainous.features.ai-gateway.providers.elevenlabs = {
          enable = true;
          secret = "elevenlabs-api-key";
        };
        # The default shell package would add another shadow entry to system.path,
        # changing D-Bus's restart trigger. Use the same nologin executable by path.
        users.users.ai-gateway.shell = "${pkgs.shadow}/bin/nologin";
      };
    };
}
