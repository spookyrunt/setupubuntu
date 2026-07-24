#!/bin/bash
set -euo pipefail

# https://docs.anythingllm.com/installation-desktop/linux#uninstalling
# Remove the installer script
rm installer.sh || true
# Remove the AppImage
rm AnythingLLMDesktop.AppImage
# Remove the .desktop file
rm ~/.local/share/applications/anythingllmdesktop.desktop
# Remove the apparmor rules
sudo rm /etc/apparmor.d/anythingllmdesktop
sudo systemctl reload apparmor
# Remove the app data fully
rm -rf ~/.config/anythingllm-desktop
