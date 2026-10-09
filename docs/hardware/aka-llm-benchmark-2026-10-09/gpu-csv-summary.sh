#!/usr/bin/env nix-shell
#!nix-shell -i bash -p gawk
# Summarize a GPU sampler CSV: peak VRAM, temps, power, per time window.
# Usage: gpu-csv-summary.sh FILE [start_epoch end_epoch]
f="$1"; s="${2:-0}"; e="${3:-9999999999}"
awk -F, -v s="$s" -v e="$e" 'NR>1 && $1>=s && $1<=e {
  n++; if($6>v)v=$6; if($2>ed)ed=$2; if($3>j)j=$3; if($4>m)m=$4; if($5>p)p=$5; ps+=$5
} END {
  printf "samples=%d vram_peak=%.0f MiB edge_peak=%.1fC junction_peak=%.1fC mem_peak=%.1fC power_peak=%.0f W power_avg=%.0f W\n",
    n, v/1048576, ed/1000, j/1000, m/1000, p/1e6, ps/n/1e6
}' "$f"
