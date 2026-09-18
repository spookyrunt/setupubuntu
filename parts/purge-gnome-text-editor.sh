#!/bin/bash
set -euo pipefail

sudo apt install -y gedit
sudo apt purge -y gnome-text-editor
sudo apt autoremove --purge -y

echo ""
echo "Finished replacing gnome-text-editor with gedit. You might want to restart your nautilus."
