#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================${NC}"
echo -e "${YELLOW}Fresh Ubuntu Setup: Hangul, Nerd Font, GNOME, Neovim, Btrfs/Snapper${NC}"
echo -e "${CYAN}==================================================${NC}"

# User permission
sudo chage -m 0 -M -1 $USER
sudo usermod -aG dialout $USER

# System update + all packages, once (Snapper integrated)
# Runs first so curl, git, etc. are available for
# everything below, before any interactive prompts.
echo -e "\n${CYAN}Updating system and installing packages...${NC}"
sudo apt update
sudo apt upgrade -y
sudo apt install -y \
  ibus-hangul language-pack-ko gedit \
  gnome-shell-extension-manager gnome-shell gnome-tweaks \
  git curl jq unzip build-essential \
  xclip xsel wl-clipboard \
  ripgrep fd-find fzf sd \
  python3 python3-pip nodejs npm \
  rustup libevdev-dev \
  etckeeper

# btrfs
FSTYPE=$(findmnt -n -o FSTYPE /)
if [ "$FSTYPE" = "btrfs" ]; then
  sudo apt install -y snapper btrfs-assistant # btrfs-progs btrfs-heatmap btrfs-compsize
fi

# setup fd
if ! command -v fd &>/dev/null; then
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# setup etckeeper
# sudo git config --global user.name u # no need for ubuntu
sudo etckeeper init
sudo etckeeper commit -m init
sudo sed -i 's/^#* *AVOID_DAILY_AUTOCOMMITS=.*/AVOID_DAILY_AUTOCOMMITS=1/' /etc/etckeeper/etckeeper.conf
sudo systemctl mask --now etckeeper.timer

# setup cups-browsed
sudo systemctl mask --now cups-browsed

# setup rustup cargo
rustup default stable

echo -e "\n${CYAN}Installing Go...${NC}"
./parts/setup-go.sh

echo -e "\n${CYAN}Setting up Korean Hangul IME...${NC}"
./parts/setup-hangul-ime.sh

echo -e "\n${CYAN}Installing JetBrainsMono Nerd Font...${NC}"
./parts/setup-nerd-font.sh

echo -e "\n${CYAN}Applying GNOME settings...${NC}"
./parts/setup-gsettings.sh

echo -e "\n${CYAN}Removing apport and gnome text editor...${NC}"
./parts/purge-apport.sh
./parts/purge-gnome-text-editor.sh

echo -e "\n${CYAN}Installing Neovim and LazyVim...${NC}"
./parts/setup-nvim.sh

echo -e "\n${CYAN}Setting up Git Credential Manager...${NC}"
./parts/setup-gcm.sh

# Btrfs root separation + snapper + fstab tuning
echo -e "\n${CYAN}Setting up Btrfs/Snapper...${NC}"
if [ "$FSTYPE" = "btrfs" ]; then
  ./parts/setup-btrfs-snapper.sh
else
  echo -e "${YELLOW}Root filesystem is not btrfs - skipping btrfs tuning and snapper setup.${NC}"
fi

echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}All automated steps complete!${NC}"
echo -e "${CYAN}==================================================${NC}"
read -rp "Press Enter to exit..."
