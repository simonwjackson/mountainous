SLKSD_SERVER_URL="http://unzen:5030"
TOKEN_FILE="$HOME/.slskd-token"

function usage() {
  echo "Usage: $0 {login|logout|search|download}"
  exit 1
}

function load_token() {
  if [ -z "$TOKEN" ] || is_token_expired; then
    login
    TOKEN=$(cat "$TOKEN_FILE")
  fi
}

function is_token_expired() {
  local expiration
  local current_time

  expiration=$(echo "$TOKEN" | jq -r '.exp')
  current_time=$(date +%s)

  [[ $expiration -le $current_time ]]
  return $?
}


function save_token() {
  local token="$1"

  echo "$token" > "$TOKEN_FILE"
}

function delete_token() {
  rm -f "$TOKEN_FILE"
}

function login() {
  local response
  local token

  response=$(
  curl \
    -s "$SLKSD_SERVER_URL/api/v0/session" \
    -X POST \
    -H 'Content-Type: application/json' \
    --data-raw "{\"username\":\"$SLKSD_USERNAME\",\"password\":\"$SLKSD_PASSWORD\"}" \
  )

  token=$(echo "$response" | jq -r '.token')

  if [ -n "$token" ] && [ "$token" != "null" ]; then
    save_token "$token"
    echo "Logged in successfully."
  else
    echo "Failed to log in."
  fi
}

# function logout() {
# ( curl -s -X POST -H "Authorization: Bearer $TOKEN" \
#   "$SLKSD_SERVER_URL/api/v1/logout"
# )
#
# delete_token
# }

function search() {
  local query="$1"

  ( curl \
    "$SLKSD_SERVER_URL/api/v0/searches" \
    -X POST \
    -H 'Accept: application/json, text/plain, */*' -H 'Accept-Encoding: gzip, deflate' -H 'Content-Type: application/json' -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1lIjoic2xza2QiLCJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1laWRlbnRpZmllciI6ImFmOTFmOGI5LTk2NDQtNDVkZi1iZjU4LWNkOTE2NTlmOTBmYyIsImh0dHA6Ly9zY2hlbWFzLm1pY3Jvc29mdC5jb20vd3MvMjAwOC8wNi9pZGVudGl0eS9jbGFpbXMvcm9sZSI6IkFkbWluaXN0cmF0b3IiLCJuYW1lIjoic2xza2QiLCJpYXQiOiIxNjgwODE5NTkyIiwibmJmIjoxNjgwODE5NTkyLCJleHAiOjE2ODE0MjQzOTIsImlzcyI6InNsc2tkIn0.VcAZ18QSkU8YknEMYABPIy7psRlSD2NSk0G6Gr7DbN4' --data-raw '{"id":"dcf1a211-1095-4f76-ae08-7bd7544bbafb","searchText":"'"$query"'"}')
      # ( curl \
      #   -s "$SLKSD_SERVER_URL/api/v0/searches" \
      #   -X POST \
      #   -H 'Content-Type: application/json' \
      #   -H "Authorization: Bearer $TOKEN" \
      #   --data-raw '{"id":"dcf1a311-1095-4f76-ae08-7bd7544bbafa","searchText":"'$1'"}'
      # )
    }

    function download() {
      local file_id="$1"

      curl -s -X POST -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"file_id\": \"$file_id\"}" \
        "$SLKSD_SERVER_URL/api/v1/downloads"
      }

      if [[ $# -eq 0 ]]; then
        usage
      fi

      load_token

      if [ -z "$TOKEN" ]; then
        echo "You are not logged in. Logging in now..."
        login
      fi

      case "$1" in
        login)
          login
          ;;
        logout)
          logout
          ;;
        search)
          shift
          search "$@"
          ;;
        download)
          shift
          download "$@"
          ;;
        *)
          usage
          ;;
      esac
