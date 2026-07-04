#!/bin/bash
set -euo pipefail

sudo apt update
sudo apt install systemd-zram-generator

sudo tee /etc/systemd/zram-generator.conf >/dev/null <<'EOF'
[zram0]
zram-size = ram * 1
EOF

sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service

swapon --show
zramctl
