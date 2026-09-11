#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install -y gir1.2-gtop-2.0 gir1.2-nm-1.0 gir1.2-clutter-1.0 gnome-system-monitor
# Install:
# gnome-extensions and gnome-tweaks
# allows use of ~/.local/share/themes/
# taskbar system monitor using gnome-system-monitor
# apps on top left
# places on top left
# removable drives on top right
# taskbar icons for legacy apps on top right
# clipboard management
sudo apt install -y \
  gnome-shell gnome-tweaks \
  gnome-shell-extension-manager \
  gnome-shell-extension-user-theme \
  gnome-shell-extension-system-monitor \
  gnome-shell-extension-apps-menu \
  gnome-shell-extension-places-menu \
  gnome-shell-extension-drive-menu \
  gnome-shell-extension-status-icons \
  gnome-shell-extension-gpaste \
  gnome-shell-extension-light-style
# gnome-shell-extension-prefs # replaced by extension-manager and gnome-extensions of gnome-shell

gnome-extensions disable tiling-assistant@ubuntu.com
gnome-extensions disable ubuntu-web-launchers@ubuntu.com

if [ -z "$(ls -A ~/.local/share/themes/Yaru-light/ 2>/dev/null)" ]; then
  mkdir -p ~/.local/share/themes/Yaru-light/
  curl -sL $(curl -s https://api.github.com/repos/spookyrunt/Yaru-light/releases/latest |
    jq -r '.assets[0].browser_download_url') |
    tar -xzv -C ~/.local/share/themes/Yaru-light/ --strip-components=1
fi
gsettings set org.gnome.shell.extensions.user-theme name "Yaru-light"
