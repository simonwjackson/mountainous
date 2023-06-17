#! /usr/bin/env nix-shell
#! nix-shell -i bash -p bash bc procps tmux 

total_cpu=0
total_mem=0
tmux_pids=$(ps -eo pid,ppid,command | grep -E "tmux: client|tmux: server" | awk '{print $1}')

for pid in $tmux_pids; do
  echo $pid
  cpu=$(ps -p $pid -o %cpu --no-headers)
  mem=$(ps -p $pid -o %mem --no-headers)
  total_cpu=$(echo "$total_cpu + $cpu" | bc)
  total_mem=$(echo "$total_mem + $mem" | bc)
done
echo "CPU: $total_cpu% MEM: $total_mem%"

