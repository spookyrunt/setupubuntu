#!/bin/bash
set -euo pipefail

# 1. Fetch the latest GCM .deb package URL
GCM_DEB_URL=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest |
  grep "browser_download_url.*linux-x64.*\.deb\"" |
  cut -d '"' -f 4)

if [ -z "$GCM_DEB_URL" ]; then
  echo "Error: Failed to fetch the GCM download URL."
  exit 1
fi

# 2. Download and install the package
wget "$GCM_DEB_URL" -O gcm-linux-x64.deb
sudo dpkg -i gcm-linux-x64.deb || sudo apt-get install -f -y

# 3. Configure Git Credential Manager
git-credential-manager configure
# git config --global credential.credentialStore cache
git config --global credential.credentialStore secretservice
git config --global core.editor "nvim"

# 4. Clean up the downloaded file
rm gcm-linux-x64.deb
