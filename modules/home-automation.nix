# The existing Home Assistant instance, not a new onboarding configuration.
# Mutable integrations, auth, registries and Zigbee state stay in /var/lib/hass.
{
  nixos.modules.home-automation =
    { config, pkgs, ... }:
    {
      services.home-assistant = {
        enable = true;
        openFirewall = true;
        package = pkgs.home-assistant.override {
          extraPackages = ps: [
            ps.grpcio
            ps.google-nest-sdm
          ];
        };
        extraComponents = [
          "default_config"
          "zha"
          "zwave_js"
          "mqtt"
          "esphome"
          "met"
          "group"
          "input_boolean"
          "input_button"
          "input_datetime"
          "input_number"
          "input_select"
          "input_text"
          "counter"
          "timer"
          "schedule"
          "google_translate"
          "tts"
          "sonos"
          "cast"
          "media_source"
          "radio_browser"
          "nest"
          "ffmpeg"
          "mobile_app"
          "cloud"
          "application_credentials"
          "roborock"
          "yeelight"
          "dhcp"
          "ssdp"
          "zeroconf"
          "usb"
          "sun"
          "zone"
          "person"
          "device_tracker"
          "history"
          "logbook"
          "recorder"
        ];
        config = {
          homeassistant = {
            name = "Home";
            unit_system = "metric";
            time_zone = "America/Denver";
            temperature_unit = "C";
            external_url = "https://habitat.hummingbird-lake.ts.net";
            internal_url = "http://localhost:8123";
          };
          automation = "!include automations.yaml";
          binary_sensor = "!include binary_sensors.yaml";
          group = "!include groups.yaml";
          input_boolean = "!include input_booleans.yaml";
          input_datetime = "!include input_datetime.yaml";
          input_number = "!include input_number.yaml";
          scene = "!include scenes.yaml";
          script = "!include scripts.yaml";
          sensor = "!include sensors.yaml";
          history = { };
          logbook = { };
          map = { };
          media_source = { };
          recorder = { };
          tts = [
            {
              platform = "google_translate";
              service_name = "google_translate_say";
            }
          ];
          http = {
            server_port = 8123;
            trusted_proxies = [
              "::1"
              "127.0.0.1"
            ];
            use_x_forwarded_for = true;
          };
        };
      };

      services.zwave-js = {
        enable = true;
        port = 3000;
        secretsConfigFile = config.sops.secrets.zwave-js-secrets.path;
      };
      users.users.hass.extraGroups = [ "dialout" ];
      # Keep the deployed ownership rather than allocate a different service UID.
      users.users.hass.uid = 286;
      users.groups.hass.gid = 286;
    };
}
