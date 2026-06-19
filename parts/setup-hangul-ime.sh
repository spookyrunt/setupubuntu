#!/bin/bash

set -euo pipefail

# Terminal Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================${NC}"
echo -e "${YELLOW}Starting Ubuntu Korean Hangul IME Setup Script${NC}"
echo -e "${CYAN}==================================================${NC}"

# 1. Install Packages using apt
echo -e "\n${CYAN}[1/3] Installing Korean Language Packs & IBus-Hangul...${NC}"
sudo apt update -y
sudo apt install -y ibus-hangul language-pack-ko

# 2. Restart IBus Background Daemon
echo -e "\n${CYAN}[2/3] Initializing and Restarting IBus Daemon...${NC}"
ibus restart

# 3. Set GNOME settings
echo -e "\n${CYAN}[3/3] Update GNOME settings...${NC}"
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}Setup Complete!{NC}"
echo -e "${CYAN}==================================================${NC}"

read -p "Press Enter to exit..."
