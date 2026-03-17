#!/usr/bin/env bash
# codexbar-oci-detail: Detailed OCI egress breakdown for popup

set -euo pipefail

export OCI_CLI_SUPPRESS_FILE_PERMISSIONS_WARNING=True
OCI_CONFIG="${OCI_CONFIG:-${HOME}/.oci/config}"
LIMIT_GB=10240  # 10 TB per tenancy

if [[ ! -f "$OCI_CONFIG" ]]; then
  echo "No OCI config found"
  exit 0
fi

NOW=$(date -u +%Y-%m-01T00:00:00Z)
END=$(date -u -d "+1 day" +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v+1d +%Y-%m-%dT00:00:00Z)
DAY=$(date +%-d)
DAYS_IN_MONTH=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%-d 2>/dev/null || date -v1d -v+1m -v-1d +%-d)

lines='<span color="#89b4fa" font_weight="bold">OCI Egress</span>\n'

for profile in $(grep '^\[' "$OCI_CONFIG" | tr -d '[]'); do
  tenancy=$(awk -v p="$profile" '
    /^\[/{found=($0 == "["p"]")} found && /^tenancy=/{sub(/^tenancy=/,""); print; exit}
  ' "$OCI_CONFIG")
  [[ -z "$tenancy" ]] && continue

  egress=$(oci --profile "$profile" usage-api usage-summary request-summarized-usages \
    --tenant-id "$tenancy" \
    --time-usage-started "$NOW" \
    --time-usage-ended "$END" \
    --granularity MONTHLY \
    --query-type USAGE \
    --filter '{"operator":"AND","dimensions":[],"tags":[],"filters":[{"operator":"OR","dimensions":[{"key":"skuName","value":"Outbound Data Transfer Zone 1"}],"tags":[],"filters":[]}]}' \
    --query 'data.items[0]."computed-quantity"' \
    --raw-output 2>/dev/null || echo "0")

  [[ "$egress" == "null" || -z "$egress" ]] && egress=0

  pct=$(echo "$egress $LIMIT_GB" | awk '{printf "%.1f", ($1 / $2) * 100}')
  used=$(echo "$egress" | awk '{printf "%.1f", $1}')
  projected=$(echo "$egress $DAY $DAYS_IN_MONTH" | awk '{printf "%.0f", ($1 / $2) * $3}')

  pct_int=${pct%.*}
  if (( pct_int >= 80 )); then
    color="#f38ba8"
  elif (( pct_int >= 50 )); then
    color="#fab387"
  else
    color="#a6e3a1"
  fi

  name="$profile"
  lines+="\\n<span color=\"#cdd6f4\">${name}</span>  <span color=\"${color}\">${pct}%</span>  <span color=\"#6c7086\">${used} GB / ${LIMIT_GB} GB</span>"
  lines+="\\n<span color=\"#6c7086\">  projected: ~${projected} GB</span>"
done

echo -e "$lines"
