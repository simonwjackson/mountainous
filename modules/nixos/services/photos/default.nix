{
  inputs,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types;
  inherit (lib.mountainous) enabled;

  cfg = config.mountainous.services.photos;
in {
  options.mountainous.services.photos = {
    enable = mkEnableOption "Whether to enable";

    tailscaleAuthFile = mkOption {
      type = types.path;
      description = "Path to the Tailscale authentication file";
      default = config.age.secrets."tailscale-ephemeral".path;
    };

    photos = mkOption {
      type = types.path;
      description = "Path to the photos directory";
    };

    address = {
      host = mkOption {
        type = types.str;
        description = "Host address for the container network";
      };

      client = mkOption {
        type = types.str;
        description = "Client address for the container network";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    containers = {
      photos = {
        hostAddress = cfg.address.host;
        localAddress = cfg.address.client;
        privateNetwork = true;
        autoStart = true;
        enableTun = true;

        bindMounts = {
          "${cfg.tailscaleAuthFile}".hostPath = cfg.tailscaleAuthFile;
          "/photos" = {
            hostPath = cfg.photos;
            isReadOnly = false;
          };
        };

        config = {...}: {
          imports = [
            inputs.self.nixosModules."networking/tailscaled"
            inputs.self.nixosModules."_profiles/container"
          ];

          mountainous = {
            profiles.container.enable = true;

            networking = {
              tailscaled = {
                enable = true;
                authKeyFile = cfg.tailscaleAuthFile;
                serve = 2283;
              };
            };
          };

          systemd.services.immich = {
            serviceConfig = {
              UMask = "0002";
            };
          };

          services.immich = {
            enable = true;
            database = {
              user = "media";
              name = "media";
            };
            user = "media";
            group = "media";
            settings = {
              backup = {
                database = {
                  cronExpression = "0 */6 * * *";
                  enabled = true;
                  keepLastAmount = 64;
                };
              };
              ffmpeg = {
                accel = "disabled";
                accelDecode = false;
                acceptedAudioCodecs = [
                  "aac"
                  "mp3"
                  "libopus"
                  "pcm_s16le"
                ];
                acceptedContainers = [
                  "mov"
                  "ogg"
                  "webm"
                ];
                acceptedVideoCodecs = [
                  "h264"
                ];
                bframes = -1;
                cqMode = "auto";
                crf = 23;
                gopSize = 0;
                maxBitrate = "0";
                preferredHwDevice = "auto";
                preset = "ultrafast";
                refs = 0;
                targetAudioCodec = "aac";
                targetResolution = "720";
                targetVideoCodec = "h264";
                temporalAQ = false;
                threads = 0;
                tonemap = "hable";
                transcode = "required";
                twoPass = false;
              };
              image = {
                colorspace = "p3";
                extractEmbedded = false;
                preview = {
                  format = "jpeg";
                  quality = 80;
                  size = 1440;
                };
                thumbnail = {
                  format = "webp";
                  quality = 80;
                  size = 250;
                };
              };
              job = {
                backgroundTask = {
                  concurrency = 5;
                };
                faceDetection = {
                  concurrency = 2;
                };
                library = {
                  concurrency = 5;
                };
                metadataExtraction = {
                  concurrency = 5;
                };
                migration = {
                  concurrency = 5;
                };
                notifications = {
                  concurrency = 5;
                };
                search = {
                  concurrency = 5;
                };
                sidecar = {
                  concurrency = 5;
                };
                smartSearch = {
                  concurrency = 2;
                };
                thumbnailGeneration = {
                  concurrency = 3;
                };
                videoConversion = {
                  concurrency = 1;
                };
              };
              library = {
                scan = {
                  cronExpression = "0 */6 * * *";
                  enabled = true;
                };
                watch = {
                  enabled = false;
                };
              };
              logging = {
                enabled = true;
                level = "log";
              };
              machineLearning = {
                clip = {
                  enabled = true;
                  modelName = "ViT-B-32__openai";
                };
                duplicateDetection = {
                  enabled = true;
                  maxDistance = {
                  };
                };
                enabled = true;
                facialRecognition = {
                  enabled = true;
                  maxDistance = {
                  };
                  minFaces = 3;
                  minScore = {
                  };
                  modelName = "buffalo_l";
                };
                url = "http://localhost:3003";
              };
              map = {
                darkStyle = "https://tiles.immich.cloud/v1/style/dark.json";
                enabled = true;
                lightStyle = "https://tiles.immich.cloud/v1/style/light.json";
              };
              metadata = {
                faces = {
                  import = false;
                };
              };
              newVersionCheck = {
                enabled = false;
              };
              notifications = {
                smtp = {
                  enabled = false;
                  from = "";
                  replyTo = "";
                  transport = {
                    host = "";
                    ignoreCert = false;
                    password = "";
                    port = 587;
                    username = "";
                  };
                };
              };
              oauth = {
                autoLaunch = false;
                autoRegister = true;
                buttonText = "Login with OAuth";
                clientId = "";
                clientSecret = "";
                defaultStorageQuota = 0;
                enabled = false;
                issuerUrl = "";
                mobileOverrideEnabled = false;
                mobileRedirectUri = "";
                profileSigningAlgorithm = "none";
                scope = "openid email profile";
                signingAlgorithm = "RS256";
                storageLabelClaim = "preferred_username";
                storageQuotaClaim = "immich_quota";
              };
              passwordLogin = {
                enabled = true;
              };
              reverseGeocoding = {
                enabled = true;
              };
              server = {
                externalDomain = "";
                loginPageMessage = "";
              };
              storageTemplate = {
                enabled = false;
                hashVerificationEnabled = true;
                template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
              };
              theme = {
                customCss = "/*\n HACK: This might hide other important buttons \n Hide Upload Button\n*/\n\n#dashboard-navbar button > div > * {\n  display: none;\n}";
              };
              trash = {
                days = 30;
                enabled = true;
              };
              user = {
                deleteDelay = 7;
              };
            };
          };

          system.stateVersion = "24.11";
        };
      };
    };
  };
}
