#!/bin/bash
set -euo pipefail

gsettings set org.gnome.desktop.interface text-scaling-factor 1.10
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT'
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.SessionManager logout-prompt false
