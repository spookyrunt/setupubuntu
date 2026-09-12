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
  gnome-shell \
  gnome-tweaks \
  gnome-shell-extension-manager \
  gnome-shell-extension-gpaste

extensions=(
  "user-theme@gnome-shell-extensions.gcampax.github.com"
  "system-monitor@gnome-shell-extensions.gcampax.github.com"
  "apps-menu@gnome-shell-extensions.gcampax.github.com"
  "places-menu@gnome-shell-extensions.gcampax.github.com"
  "drive-menu@gnome-shell-extensions.gcampax.github.com"
  "status-icons@gnome-shell-extensions.gcampax.github.com"
  "light-style@gnome-shell-extensions.gcampax.github.com"
)

# Download and install
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
shell_api="$(gnome-shell --version | grep -oE '[0-9]+(\.[0-9]+)+' | cut -d. -f1)"
for uuid in "${extensions[@]}"; do
  printf 'Installing %s...\n' "$uuid"
  if curl -fsSL --retry 2 \
    "https://extensions.gnome.org/download-extension/${uuid}.shell-extension.zip?shell_version=${shell_api}" \
    -o "$tmpdir/${uuid}.zip"; then
    gnome-extensions install --force "$tmpdir/${uuid}.zip" ||
      printf 'Install failed: %s\n' "$uuid"
  else
    printf 'Download failed or unsupported: %s\n' "$uuid"
  fi
done

# Enable or disable
for uuid in "${extensions[@]}"; do
  gnome-extensions enable "$uuid" || true
done
gnome-extensions enable GPaste@gnome-shell-extensions.gnome.org || true
gnome-extensions disable tiling-assistant@ubuntu.com || true
gnome-extensions disable web-search-provider@ubuntu.com || true

echo "Done. You may reboot."
