#!/bin/bash
set -euo pipefail

# Terminal Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================${NC}"
echo -e "${YELLOW}Starting Nerd Font Installation Script${NC}"
echo -e "${CYAN}==================================================${NC}"

# 1. Install required system utilities
echo -e "\n${CYAN}[1/3] Installing required system utilities...${NC}"
sudo apt update -y
sudo apt install -y unzip fontconfig curl

# 2. Download and install JetBrainsMono Nerd Font
FONT_DIR="$HOME/.local/share/fonts"
echo -e "\n${CYAN}[2/3] Downloading JetBrainsMono Nerd Font to $FONT_DIR...${NC}"
mkdir -p "$FONT_DIR"

# Download the latest release package and extract it
curl -fLo "$FONT_DIR/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
rm "$FONT_DIR/JetBrainsMono.zip"

# Refresh the system font cache
echo -e "Updating font cache..."
fc-cache -f "$FONT_DIR"

# 3. Display manual profile configuration summary
echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}[SUCCESS] Font downloaded and cached locally!${NC}"
echo -e "${CYAN}--------------------------------------------------${NC}"
echo -e "${YELLOW}You may apply the font manually to your terminal:${NC}"
echo -e "1. Open your terminal application settings/preferences."
echo -e "2. Locate the active profile configuration or text preferences."
echo -e "3. Turn off 'Use system font' if checked."
echo -e "4. Select ${GREEN}'JetBrainsMono Nerd Font'${NC} from the font selection menu."
echo -e "5. Save and restart your active terminal window."
echo -e "${CYAN}==================================================${NC}"

read -p "Press Enter to exit..."
