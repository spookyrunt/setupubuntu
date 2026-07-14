#!/bin/bash
set -euo pipefail

if [ -z "$(ls -A ~/.local/share/themes/Yaru-light/ 2>/dev/null)" ]; then
  mkdir -p ~/.local/share/themes/Yaru-light/
  curl -sL $(curl -s https://api.github.com/repos/spookyrunt/Yaru-light/releases/latest |
    jq -r '.assets[0].browser_download_url') |
    tar -xzv -C ~/.local/share/themes/Yaru-light/ --strip-components=1
fi

echo "Look for User Themes:"
extension-manager
