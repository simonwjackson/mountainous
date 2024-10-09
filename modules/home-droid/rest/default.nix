{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) mkEnableOption mkOption types mkIf;

  cfg = config.services.http-server;
  service = "${config.home.homeDirectory}/.local/bin/start-http-server.sh";
  http-server = "${config.home.homeDirectory}/.local/bin/http-server.py";
  http-endpoints = "${config.home.homeDirectory}/.local/bin/http-endpoints.sh";
in {
  options.services.http-server = {
    enable = mkEnableOption "Nix-on-Droid HTTP Server";

    port = mkOption {
      type = types.port;
      default = 9999;
      description = "Port on which the HTTP server should listen";
    };
  };

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      python3
      jq
      gum
    ];

    home.file."${http-server}" = {
      executable = true;
      text =
        # python
        ''
          #!/usr/bin/env python3

          import http.server
          import socketserver
          import json
          import subprocess
          from urllib.parse import urlparse, parse_qs

          PORT = ${toString cfg.port}

          class APIHandler(http.server.SimpleHTTPRequestHandler):
              def do_GET(self):
                  parsed_path = urlparse(self.path)
                  if parsed_path.path == '/api':
                      query_params = parse_qs(parsed_path.query)

                      # Convert query parameters to JSON
                      params_json = json.dumps(query_params)

                      # Call the bash script and pass the JSON as an argument
                      result = subprocess.run(['${http-endpoints}', params_json], capture_output=True, text=True)

                      self.send_response(200)
                      self.send_header('Content-type', 'application/json')
                      self.end_headers()
                      self.wfile.write(result.stdout.encode())
                  else:
                      self.send_error(404, "Not Found")

          if __name__ == "__main__":
              with socketserver.TCPServer(("", PORT), APIHandler) as httpd:
                  print(f"Serving at port {PORT}")
                  httpd.serve_forever()
        '';
    };

    home.file."${http-endpoints}" = {
      executable = true;
      text =
        # python
        ''
          #!/usr/bin/env bash

          set -euo pipefail

          doc="API Processing Script

          Usage:
            $(basename "$0") <json_params>
            $(basename "$0") -h | --help

          Options:
            -h, --help         Show this screen.
          "

          log() {
            local level="$1"
            shift
            gum log --level "$level" "$@"
          }

          main() {
            local params="$1"
            local endpoint

            # Extract the 'endpoint' parameter from the JSON
            endpoint=$(echo "$params" | jq -r '.endpoint[]? // "default"')

            case "$endpoint" in
            "hello")
              name=$(echo "$params" | jq -r '.name[]? // "World"')
              echo "{\"message\": \"Hello, $name!\"}"
              ;;
            "time")
              current_time=$(date +"%Y-%m-%d %H:%M:%S")
              echo "{\"current_time\": \"$current_time\"}"
              ;;
            *)
              log warn "Unknown endpoint: $endpoint"
              echo "{\"error\": \"Unknown endpoint\"}"
              ;;
            esac
          }

          if [[ "''${BASH_SOURCE[0]}" == "''${0}" ]]; then
            if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
              echo "$doc"
              exit 0
            fi
            main "$@"
          fi
        '';
    };

    home.file."${service}" = {
      executable = true;
      text =
        # bash
        ''
          #!/bin/sh
          if [ ! -f /tmp/http-server.pid ]; then
            nohup ${http-server} > ${config.home.homeDirectory}/http-server.log 2>&1 &
            echo $! > /tmp/http-server.pid
          fi
        '';
    };

    programs.bash.initExtra = service;
  };
}
