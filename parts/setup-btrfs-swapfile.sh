#!/bin/bash
set -euo pipefail

sudo swapoff /swapfile
sudo rm /swapfile
sudo btrfs filesystem mkswapfile --size 16g /swapfile
sudo swapon /swapfile
swapon --show
free -h
