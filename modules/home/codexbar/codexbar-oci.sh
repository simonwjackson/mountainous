#!/usr/bin/env bash
# codexbar-oci: OCI egress usage for ironbar label
# Shows combined egress percentage across all OCI tenancies

set -euo pipefail

OCI_CONFIG="${OCI_CONFIG:-${HOME}/.oci/config}"
LIMIT_GB=10240  # 10 TB per tenancy

if [[ ! -f "$OCI_CONFIG" ]]; then
  echo '<span color="#6c7086">OCI:--</span>'
  exit 0
fi

NOW=$(date -u +%Y-%m-01T00:00:00Z)
END=$(date -u -d "+1 day" +%Y-%m-%dT00:00:00Z 2>/dev/null || date -u -v+1d +%Y-%m-%dT00:00:00Z)

# Collect egress for each profile
max_pct=0

for profile in $(grep '^\[' "$OCI_CONFIG" | tr -d '[]'); do
  tenancy=$(oci --profile "$profile" iam region-subscription list --query 'data[0]."tenancy-id"' --raw-output 2>/dev/null || true)
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
  is_higher=$(echo "$pct $max_pct" | awk '{print ($1 > $2) ? 1 : 0}')
  [[ "$is_higher" == "1" ]] && max_pct="$pct"
done

pct_int=${max_pct%.*}
if (( pct_int >= 80 )); then
  echo "<span color=\"#f38ba8\">OCI:${max_pct}%</span>"
elif (( pct_int >= 50 )); then
  echo "<span color=\"#fab387\">OCI:${max_pct}%</span>"
else
  echo "<span color=\"#a6e3a1\">OCI:${max_pct}%</span>"
fi
