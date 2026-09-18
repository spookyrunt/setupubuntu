#!/bin/bash
set -euo pipefail

gsettings set org.gnome.desktop.interface text-scaling-factor 1.10
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.SessionManager logout-prompt false
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT'
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts-only-mounted true
# gsettings set org.gnome.mutter center-new-windows false
gsettings set org.gnome.mutter attach-modal-dialogs false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver lock-delay 0
gsettings set org.gnome.desktop.session idle-delay 900
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 0
gsettings set org.gnome.settings-daemon.plugins.color night-light-enabled true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-light'
