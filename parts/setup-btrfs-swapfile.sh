#!/bin/bash
set -euo pipefail

mem_total_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
default_size_gib=$(((mem_total_kb + 1048575) / 1048576))

read -p "Enter swap file size in GiB [Default: ${default_size_gib}]: " user_input

if [ -z "${user_input}" ]; then
  swap_size_gib=${default_size_gib}
elif [[ ! "${user_input}" =~ ^[0-9]+$ ]] || [ "${user_input}" -le 0 ]; then
  echo "Error: Invalid size. Please enter a positive integer." >&2
  exit 1
else
  swap_size_gib=$((user_input))
fi

echo "Setting up a ${swap_size_gib}GiB swapfile..."

swapon --show | grep -q '/swapfile' && sudo swapoff /swapfile
sudo rm /swapfile
sudo btrfs filesystem mkswapfile --size "${swap_size_gib}g" /swapfile
sudo swapon /swapfile
grep --quiet '/swapfile' /etc/fstab || echo "/swapfile none swap defaults 0 0" | sudo tee --append /etc/fstab >/dev/null
swapon --show
free -h
