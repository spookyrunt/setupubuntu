#!/bin/bash
set -euo pipefail

sudo apt update -y
sudo apt install -y bluez bluez-tools blueman
sudo systemctl enable --now bluetooth
