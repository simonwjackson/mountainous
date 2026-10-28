# Production front door and per-client grants.
{
  inputs,
  self,
  lib,
  ...
}:
let
  piHosts = lib.filter (
    host: self.nixosConfigurations.${host}.config.mountainous.appProfiles.pi.enable or false
  ) (lib.attrNames self.nixosConfigurations);
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
            systemoneCharges = {
              # Typesafe: $42/billion input tokens, output free; ~2,400 tokens/call ceiling.
              # https://typesafe.ai/, checked 2026-10-27.
              jev = 0.0001;
              # Upstage: $0.10/M input tokens, output free; see modules/decision-gateway.nix.
              solar = 0.0003;
            };
            modelPrices = {
              # Google pricing updated 2026-10-27: flash $0.045/0.5K, $0.067/1K,
              # $0.101/2K, $0.151/4K, plus $0.50/M input tokens. A call whose
              # tier the front door does not know reserves the 4K ceiling.
              # https://ai.google.dev/gemini-api/docs/pricing, checked 2026-10-28.
              "gemini-3.1-flash-image" = {
                image_per_unit = 0.151;
                image_per_size = {
                  "512" = 0.045;
                  "1K" = 0.067;
                  "2K" = 0.101;
                  "4K" = 0.151;
                };
                input_per_million = 0.50;
              };
              # Google: pro $0.134/1K or 2K, $0.24/4K, plus $2/M input tokens.
              # https://ai.google.dev/gemini-api/docs/pricing, checked 2026-10-28.
              "gemini-3-pro-image" = {
                image_per_unit = 0.24;
                image_per_size = {
                  "1K" = 0.134;
                  "2K" = 0.134;
                  "4K" = 0.24;
                };
                input_per_million = 2.0;
              };
            };
            gatewayKeys =
              _:
              [
                {
                  name = "assistant@rakku";
                  secret = "ai-gateway-key-assistant-rakku";
                  credential = "assistant";
                  # systemone and jev: core's reflexes, thread choice and
                  # recall ask Jev here (assistant ADR 0001).
                  dialects = [
                    "codex"
                    "models"
                    "responses"
                    "systemone"
                  ];
                  models = [
                    "claude-opus-5-5"
                    "gpt-6.1-sol"
                    "gemini-3.8-flash-high"
                    "gpt-5.6-luna"
                    "jev"
                  ];
                  # Jev is the one paid model here, at the fixed $0.0001 charge
                  # per call. About 12,000 calls a month are expected; past the
                  # cap, core falls back to its rules (assistant ADR 0001).
                  monthly_cap_usd = 5;
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
                {
                  name = "storia@zao";
                  secret = "ai-gateway-key-storia-zao";
                  credential = "storia-zao";
                  dialects = [
                    "messages"
                    "systemone"
                  ];
                  models = [
                    "claude-opus-5-5"
                    "jev"
                  ];
                  monthly_cap_usd = 1;
                  requests_per_minute = 120;
                }
                {
                  name = "korri@zao";
                  secret = "ai-gateway-key-korri-zao";
                  credential = "korri-zao";
                  dialects = [ "images" ];
                  models = [
                    "gemini-3.1-flash-image"
                    "gemini-3-pro-image"
                    "gpt-image-2"
                  ];
                  monthly_cap_usd = 5;
                  requests_per_minute = 30;
                }
              ]
              ++ map (host: {
                name = "pi@${host}";
                secret = "ai-gateway-key-pi-${host}";
                credential = "pi-${host}";
                dialects = [
                  "codex"
                  "models"
                  "responses"
                  "systemone"
                ]
                ++ lib.optional (host == "zao") "images";
                models = [ "*" ];
                monthly_cap_usd = 1;
                requests_per_minute = if host == "zao" then 1200 else 600;
              }) ([ "zao" ] ++ piHosts);
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
