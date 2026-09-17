#!/bin/bash
set -euo pipefail

# Install language packs and IBus-Hangul
sudo apt install -y ibus-hangul language-pack-ko

# Restart IBus daemon
ibus restart

# Set GNOME settings
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"
