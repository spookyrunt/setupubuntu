#!/bin/bash
set -euo pipefail

# https://flathub.org/en/setup/Ubuntu
sudo apt install -y flatpak gnome-software-plugin-flatpak
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
