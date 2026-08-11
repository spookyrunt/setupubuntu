#!/bin/bash
set -euo pipefail

gsettings set org.gnome.desktop.interface text-scaling-factor 1.10
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT' || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts-only-mounted true || true
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.SessionManager logout-prompt false
gsettings set org.gnome.mutter center-new-windows false
gsettings set org.gnome.mutter attach-modal-dialogs false
