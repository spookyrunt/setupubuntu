#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install -y gedit
sudo apt purge -y gnome-text-editor
sudo apt autoremove --purge -y
echo "You might want to restart your nautilus."
