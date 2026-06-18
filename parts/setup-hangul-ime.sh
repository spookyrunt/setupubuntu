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
echo -e "\n${CYAN}[1/2] Installing Korean Language Packs & IBus-Hangul...${NC}"
sudo apt update -y
sudo apt install -y ibus-hangul language-pack-ko

# 2. Restart IBus Background Daemon
echo -e "\n${CYAN}[2/2] Initializing and Restarting IBus Daemon...${NC}"
ibus restart

# 3. Final Instructions for Manual Binding
echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}Backend Setup Complete! Follow Steps 4 and 5 Manually:${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "1. Open ${GREEN}Settings -> Keyboard${NC}."
echo -e "2. Under 'Input Sources', click ${GREEN}[+] (Add)${NC} -> click ${GREEN}[...] (More)${NC}."
echo -e "3. Search for 'Korean' and select ${YELLOW}Korean (Hangul)${NC}."
echo -e "4. Click the 3 dots next to it -> ${GREEN}Preferences${NC} -> Add your physical ${YELLOW}한/영 key${NC}."
echo -e "${CYAN}==================================================${NC}"

read -p "Press Enter to exit..."
