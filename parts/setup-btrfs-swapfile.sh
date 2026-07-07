#!/bin/bash
set -euo pipefail

swapon --show | grep -q '/swapfile' && sudo swapoff /swapfile
sudo rm /swapfile
sudo btrfs filesystem mkswapfile --size 32g /swapfile
sudo swapon /swapfile
swapon --show
free -h
