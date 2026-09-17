#!/bin/bash
set -euo pipefail

sudo apt install -y unzip fontconfig curl

if [ -f ~/.local/share/fonts/JetBrainsMonoNerdFont-Regular.ttf ]; then
  echo "JetBrainsMono Nerd Font is already installed. Skipping..."
  exit 0
fi

mkdir -p ~/.local/share/fonts
curl -fLo ~/.local/share/fonts/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o ~/.local/share/fonts/JetBrainsMono.zip -d ~/.local/share/fonts
rm ~/.local/share/fonts/JetBrainsMono.zip

fc-cache -f ~/.local/share/fonts

# echo ""
# echo "[SUCCESS] Font downloaded and cached locally!"
# echo "--------------------------------------------------"
# echo "You may apply the font manually to your terminal:"
# echo "1. Open your terminal application settings/preferences."
# echo "2. Locate the active profile configuration or text preferences."
# echo "3. Turn off 'Use system font' if checked."
# echo "4. Select 'JetBrainsMono Nerd Font' from the font selection menu."
# echo "5. Save and restart your active terminal window."
# echo "=================================================="
