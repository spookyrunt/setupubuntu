#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install gedit
sudo apt purge gnome-text-editor
sudo apt autoremove --purge -y
echo "You might want to restart your nautilus."
