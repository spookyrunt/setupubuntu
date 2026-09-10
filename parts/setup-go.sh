#!/bin/bash
set -euo pipefail

sudo apt update -y
sudo apt install -y git curl jq

GO_VERSION="$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -er '.[0].version')"
CURRENT_VERSION="$(go version 2>/dev/null | awk '{print $3}' || true)"

if [[ "$CURRENT_VERSION" == "$GO_VERSION" ]]; then
  echo "Go is already installed and up to date ($CURRENT_VERSION). Skipping."
  exit 0
fi

GO_FILE="${GO_VERSION}.linux-amd64.tar.gz"
curl -fLO "https://go.dev/dl/${GO_FILE}"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "$GO_FILE"
rm -f "$GO_FILE"

# export go bin
if ! grep -q 'export PATH="$PATH:$HOME/go/bin"' ~/.profile 2>/dev/null; then
  printf '\nexport PATH="$PATH:$HOME/go/bin"' >>~/.profile
fi
if ! grep -q 'export PATH="$PATH:/usr/local/go/bin"' ~/.profile 2>/dev/null; then
  printf '\nexport PATH="$PATH:/usr/local/go/bin"' >>~/.profile
fi

echo "Installed: ${GO_VERSION}"
