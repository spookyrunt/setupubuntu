#!/bin/bash
set -euo pipefail

sudo apt update -y
sudo apt install cargo -y

# if ! grep -q 'export PATH="$HOME/.cargo/bin:$PATH"' ~/.profile 2>/dev/null; then
#   printf '\nexport PATH="$HOME/.cargo/bin:$PATH"' >>~/.profile
# fi

sudo cargo install dualboot-bt-link-keys --root /usr/local
sudo chmod +rx /usr/local/bin/dualboot-bt-link-keys

echo 'Run: sudo dualboot-bt-link-keys /mnt/YOUR_MOUNT_POINT --write --restart-bluetooth'
