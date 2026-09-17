#!/bin/bash
set -euo pipefail

# 1. Fetch the latest GCM .deb package URL
GCM_DEB_URL=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest |
  grep "browser_download_url.*linux-x64.*\.deb\"" |
  cut -d '"' -f 4 || true)

if [ -z "$GCM_DEB_URL" ]; then
  echo "Error: Failed to fetch the GCM download URL. Skipping installation."
  exit 1
fi

# 2. Download and install the package (skip if already present)
if type -p git-credential-manager >/dev/null 2>&1; then
  echo "Git Credential Manager is already installed. Skipping installation."
else
  wget "$GCM_DEB_URL" -O /tmp/gcm-linux-x64.deb
  sudo dpkg --install /tmp/gcm-linux-x64.deb || sudo apt-get install -f -y
  rm /tmp/gcm-linux-x64.deb
fi

# 3. Configure Git Credential Manager
git-credential-manager configure
git config --global credential.credentialStore secretservice
git config --global core.editor "nvim"
echo "Git Credential Manager configured with secretservice."
