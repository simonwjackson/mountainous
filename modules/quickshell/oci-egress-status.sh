#!/usr/bin/env bash
# One monthly OCI outbound transfer reading per configured profile.
# TSV: profile, percentage of 10 TB, used GB, projected GB at month's end.
set -euo pipefail
export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True
config=${OCI_CONFIG:-/run/secrets/oci-config}
if [[ ! -r "$config" ]]; then
  printf 'unavailable\n'
  exit 0
fi

start=$(date -u +%Y-%m-01T00:00:00Z)
end=$(date -u -d '+1 day' +%Y-%m-%dT00:00:00Z)
day=$(date -u +%-d)
days=$(date -u -d "$(date -u +%Y-%m-01) +1 month -1 day" +%-d)
found=0
while IFS= read -r profile; do
  [[ -n "$profile" ]] || continue
  tenancy=$(awk -v p="$profile" '
    /^\[/{found=($0 == "["p"]")} found && /^tenancy[[:space:]]*=/{sub(/^[^=]*=[[:space:]]*/, ""); print; exit}
  ' "$config")
  [[ -n "$tenancy" ]] || continue
  found=1
  value=$(timeout 40 oci --config-file "$config" --profile "$profile" \
    usage-api usage-summary request-summarized-usages \
    --tenant-id "$tenancy" --time-usage-started "$start" --time-usage-ended "$end" \
    --granularity MONTHLY --query-type USAGE \
    --filter '{"operator":"AND","dimensions":[],"tags":[],"filters":[{"operator":"OR","dimensions":[{"key":"skuName","value":"Outbound Data Transfer Zone 1"}],"tags":[],"filters":[]}]}' \
    --query 'data.items[0]."computed-quantity"' --raw-output 2>/dev/null) || value=error
  if [[ "$value" == error ]]; then
    printf '%s\t--\t--\t--\n' "$profile"
  else
    [[ -n "$value" && "$value" != null ]] || value=0
    if [[ ! "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      printf '%s\t--\t--\t--\n' "$profile"
      continue
    fi
    awk -v name="$profile" -v used="$value" -v day="$day" -v days="$days" \
      'BEGIN {printf "%s\t%.1f\t%.1f\t%.0f\n", name, used/10240*100, used, used/day*days}'
  fi
done < <(awk '/^\[/{gsub(/\[|\]/, ""); print}' "$config")
if (( ! found )); then printf 'unavailable\n'; fi
