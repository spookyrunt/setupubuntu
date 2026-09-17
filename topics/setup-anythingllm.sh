#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install -y libfuse2

# https://docs.anythingllm.com/installation-desktop/linux#install-using-the-installer-script
cd
curl -fsSL https://cdn.anythingllm.com/latest/installer.sh -o installer.sh
chmod +x installer.sh
./installer.sh
