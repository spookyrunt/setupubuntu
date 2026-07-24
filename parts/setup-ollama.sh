#!/bin/bash
set -euo pipefail

is_btrfs() {
  [ "$(stat -f -c %T "$1" 2>/dev/null)" = "btrfs" ]
}

SYSTEM_DIR="/usr/share/ollama"
USER_DIR="$HOME/.ollama"

echo ">>> Starting pre-installation Btrfs NOCOW configuration..."

# 1. System directory setup
sudo mkdir -p "$SYSTEM_DIR"
if is_btrfs "$SYSTEM_DIR"; then
  sudo chattr -R +C "$SYSTEM_DIR"
  echo "[OK] NOCOW applied: $SYSTEM_DIR"
else
  echo "[INFO] $SYSTEM_DIR not on Btrfs, skipping"
fi

# 2. User directory setup
mkdir -p "$USER_DIR"
if is_btrfs "$USER_DIR"; then
  chattr -R +C "$USER_DIR"
  echo "[OK] NOCOW applied: $USER_DIR"
else
  echo "[INFO] $USER_DIR not on Btrfs, skipping"
fi

echo ">>> Pre-configuration complete. Running the official Ollama installer..."
echo "--------------------------------------------------------"

curl -fsSL https://ollama.com/install.sh | sh

RAM=$(free -m | awk '/^Mem:/{print $2}')
sudo sed -i "/\[Service\]/a Environment=\"OLLAMA_HOST=0.0.0.0:11434\"\nEnvironment=\"OLLAMA_CONTEXT_LENGTH=${RAM}\"" /etc/systemd/system/ollama.service
sudo systemctl daemon-reload
sudo systemctl restart ollama.service
