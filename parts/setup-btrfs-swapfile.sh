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

# subvolume
sudo btrfs subvolume show /@swap || sudo rm -rf /@swap
[ -d /@swap ] || sudo btrfs subvolume create /@swap

# off /@swap/swapfile
swapon --show | grep -q '/@swap/swapfile' && sudo swapoff /@swap/swapfile
[ -f /@swap/swapfile ] && sudo rm /@swap/swapfile

# off /swapfile
swapon --show | grep -q '/swapfile' && sudo swapoff /swapfile
[ -f /swapfile ] && sudo rm /swapfile

# swap on
sudo btrfs filesystem mkswapfile --size "${swap_size_gib}g" /@swap/swapfile
sudo swapon /@swap/swapfile

# fstab
sudo sed -i '\|^/swapfile |d' /etc/fstab
grep --quiet '^/@swap/swapfile ' /etc/fstab ||
  echo "/@swap/swapfile none swap defaults 0 0" | sudo tee --append /etc/fstab

# fin
swapon --show
free -h
