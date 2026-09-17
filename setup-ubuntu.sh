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
  curl git unzip build-essential \
  xclip xsel wl-clipboard \
  ripgrep fd-find fzf sd \
  python3 python3-pip nodejs npm \
  rustup libevdev-dev \
  etckeeper \
  snapper btrfs-assistant # btrfs-progs btrfs-heatmap btrfs-compsize

# setup fd nvim uses
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

# export go bin
if ! grep -q 'export PATH="$PATH:$HOME/go/bin"' ~/.profile 2>/dev/null; then
  printf '\nexport PATH="$PATH:$HOME/go/bin"' >>~/.profile
fi
if ! grep -q 'export PATH="$PATH:/usr/local/go/bin"' ~/.profile 2>/dev/null; then
  printf '\nexport PATH="$PATH:/usr/local/go/bin"' >>~/.profile
fi

ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)
echo "Detected root filesystem type: ${ROOT_FSTYPE}"

# Hangul IME
echo -e "\n${CYAN}Setting up Korean Hangul IME...${NC}"
ibus restart
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

# Nerd Font
echo -e "\n${CYAN}Installing JetBrainsMono Nerd Font...${NC}"
FONT_DIR="$HOME/.local/share/fonts"
if [ -f "$FONT_DIR/JetBrainsMonoNerdFont-Regular.ttf" ]; then
  echo "JetBrainsMono Nerd Font is already installed. Skipping..."
else
  mkdir -p "$FONT_DIR"
  curl -fLo "$FONT_DIR/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
  unzip -o "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
  rm "$FONT_DIR/JetBrainsMono.zip"
  fc-cache -f "$FONT_DIR"
fi

# GNOME settings
echo -e "\n${CYAN}Applying GNOME settings...${NC}"
gsettings set org.gnome.desktop.interface text-scaling-factor 1.10
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.SessionManager logout-prompt false
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT' || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts-only-mounted true || true
# gsettings set org.gnome.mutter center-new-windows false
gsettings set org.gnome.mutter attach-modal-dialogs false
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.desktop.screensaver lock-delay 0
gsettings set org.gnome.desktop.session idle-delay 900

# Purge Apport and GNOME Text Editor
[ -f "/etc/default/apport" ] && sudo sed -i 's/enabled=1/enabled=0/' /etc/default/apport
sudo apt purge -y 'apport*' gnome-text-editor
sudo apt autoremove --purge -y
sudo rm -rf /var/crash/*

# Neovim + LazyVim
echo -e "\n${CYAN}Installing Neovim and LazyVim...${NC}"

for _ in 1; do
  RELEASE_JSON="$(
    curl -fsSL https://api.github.com/repos/neovim/neovim/releases/latest
  )"
  NVIM_LATEST_TAG="$(jq -er '.tag_name' <<<"$RELEASE_JSON")"
  CURRENT_VERSION="$(
    nvim --version 2>/dev/null |
      sed -n '1s/^NVIM //p' ||
      true
  )"
  if [[ "$CURRENT_VERSION" == "$NVIM_LATEST_TAG" ]]; then
    echo "Neovim is already installed and up to date (${CURRENT_VERSION}). Skipping."
    break
  fi

  NVIM_URL="$(
    jq -er '
    .assets[]
    | select(.name == "nvim-linux-x86_64.tar.gz")
    | .browser_download_url
  ' <<<"$RELEASE_JSON"
  )"
  if [[ -z "$NVIM_URL" || "$NVIM_URL" == "null" ]]; then
    echo "Error: Failed to fetch the Neovim download URL."
    exit 1
  fi
  curl -L "$NVIM_URL" -o /tmp/nvim-linux-x86_64.tar.gz
  tar xzf /tmp/nvim-linux-x86_64.tar.gz -C /tmp
  sudo rm -rf /opt/nvim
  sudo mv /tmp/nvim-linux-x86_64 /opt/nvim
  sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
  rm /tmp/nvim-linux-x86_64.tar.gz
  echo "Neovim $(nvim --version | head -1) installed."

  sudo update-alternatives --install /usr/bin/editor editor /usr/local/bin/nvim 60
  sudo update-alternatives --set editor /usr/local/bin/nvim
  if ! grep -q "export EDITOR=/usr/local/bin/nvim" ~/.profile 2>/dev/null; then
    printf '\nexport EDITOR=/usr/local/bin/nvim' >>~/.profile
  fi
  if ! grep -q "export VISUAL=/usr/local/bin/nvim" ~/.profile 2>/dev/null; then
    printf '\nexport VISUAL=/usr/local/bin/nvim' >>~/.profile
  fi
  git config --global core.editor "nvim"
  sudo git config --global core.editor "nvim"
  echo "Registered nvim as system default editor."

  # Back up existing config if present
  [ -d ~/.config/nvim ] && mv ~/.config/nvim ~/.config/nvim.bak.$(date +%s)
  git clone https://github.com/LazyVim/starter ~/.config/nvim
  rm -rf ~/.config/nvim/.git

  mkdir -p ~/.config/nvim/lua/plugins
  cat >~/.config/nvim/lua/plugins/colorscheme.lua <<'EOF'
return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-latte",
    },
  },
}
EOF

  cat >~/.config/nvim/lua/plugins/korean.lua <<'EOF'
return {
  {
    "kiyoon/Korean-IME.nvim",
    keys = {
      {
        "<f12>",
        function() require("korean_ime").change_mode() end,
        mode = { "i", "n", "x", "s" },
        desc = "한/영",
      },
    },
    config = function()
      require("korean_ime").setup()
      vim.keymap.set("i", "<f9>", function()
        require("korean_ime").convert_hanja()
      end, { noremap = true, silent = true, desc = "한자" })
    end,
  },
}
EOF

  cat >~/.config/nvim/lua/plugins/vimbegood.lua <<'EOF'
return {
  {
    "ThePrimeagen/vim-be-good",
    lazy = false,
  },
}
EOF
  echo "LazyVim is installed."
done

# Git Credential Manager (GCM)
echo -e "\n${CYAN}Installing and configuring Git Credential Manager...${NC}"

for _ in 1; do
  GCM_DEB_URL=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest |
    grep "browser_download_url.*linux-x64.*\.deb\"" |
    cut -d '"' -f 4 || true)
  if [ -z "$GCM_DEB_URL" ]; then
    echo -e "${RED}Error: Failed to fetch the GCM download URL. Skipping installation.${NC}"
    break
  fi

  if type -p git-credential-manager >/dev/null 2>&1; then
    echo "Git Credential Manager is already installed. Skipping installation."
  else
    wget "$GCM_DEB_URL" -O /tmp/gcm-linux-x64.deb
    sudo dpkg --install /tmp/gcm-linux-x64.deb || sudo apt-get install -f -y
    rm /tmp/gcm-linux-x64.deb
  fi

  git-credential-manager configure
  git config --global credential.credentialStore secretservice
  echo "Git Credential Manager configured with secretservice."
done

# Btrfs root separation + snapper + fstab tuning
echo -e "\n${CYAN}Checking filesystem and configuring Btrfs/Snapper...${NC}"
if [ "$ROOT_FSTYPE" = "btrfs" ]; then
  echo -e "${GREEN}Root filesystem is btrfs — separating root, tuning fstab, and configuring snapper.${NC}"

  # Separate root subvolume from snapshot tree
  # Must run BEFORE snapper starts taking automated snapshots, so the
  # root we end up on is a clean, independent subvolume rather than
  # something nested under .snapshots.
  ROOT_DEV=$(findmnt -no UUID /)
  ROOT_DEV="/dev/disk/by-uuid/${ROOT_DEV}"
  echo "Root device: $ROOT_DEV"

  sudo mkdir -p /mnt/topsetup
  sudo mount -o subvolid=5 "$ROOT_DEV" /mnt/topsetup
  trap 'umount /mnt/topsetup 2>/dev/null || true' EXIT

  CURRENT_DEFAULT_PATH=$(sudo btrfs subvolume get-default / | awk '{print $NF}')
  NEW_ROOT_NAME="@"

  if [[ "$CURRENT_DEFAULT_PATH" == *".snapshots/"* ]]; then
    echo "Current root is inside a snapshot path. Separating it."
    SRC_PATH="/mnt/topsetup/${CURRENT_DEFAULT_PATH#<FS_TREE>/}"

    # If @ already exists from a previous run, it's stale after a rollback
    # (it doesn't reflect this rollback's content) and is not currently
    # mounted as root (the active root is under .snapshots/, per the
    # condition above), so it's safe to delete and recreate fresh.
    if [ -d "/mnt/topsetup/${NEW_ROOT_NAME}" ]; then
      echo "${NEW_ROOT_NAME} already exists but is stale after a rollback. Replacing it."
      sudo btrfs subvolume delete "/mnt/topsetup/${NEW_ROOT_NAME}"
    fi

    sudo btrfs subvolume snapshot "$SRC_PATH" "/mnt/topsetup/${NEW_ROOT_NAME}"
    NEW_ID=$(sudo btrfs subvolume list /mnt/topsetup | grep "path ${NEW_ROOT_NAME}$" | awk '{print $2}')
    sudo btrfs subvolume set-default "$NEW_ID" /mnt/topsetup
    echo "Default subvolume set to ${NEW_ROOT_NAME} (ID ${NEW_ID})."
    ROOT_SEPARATED=1
  else
    echo "Already an independent subvolume structure. No change."
    ROOT_SEPARATED=0
  fi

  sudo umount /mnt/topsetup

  # setup snapper
  echo "Configuring Snapper..."
  [ -f /etc/snapper/configs/root ] || sudo snapper -c root create-config /
  sudo snapper -c root set-config \
    TIMELINE_CREATE=yes \
    TIMELINE_CLEANUP=yes \
    TIMELINE_LIMIT_HOURLY=2 \
    TIMELINE_LIMIT_DAILY=2 \
    TIMELINE_LIMIT_WEEKLY=2 \
    TIMELINE_LIMIT_MONTHLY=1 \
    TIMELINE_LIMIT_YEARLY=0 \
    NUMBER_CLEANUP=yes \
    NUMBER_LIMIT=5 \
    NUMBER_LIMIT_IMPORTANT=5

  echo "Creating APT hook for Snapper..."
  sudo tee /etc/apt/apt.conf.d/80snapper >/dev/null <<EOF
DPkg::Pre-Invoke {"[ -x /usr/bin/snapper ] && /usr/bin/snapper -c root create --print-number -t pre --cleanup-algorithm number -d 'APT Pre-Invoke' > /run/snapper-apt-pre-number 2>/dev/null || true";};
DPkg::Post-Invoke {"[ -x /usr/bin/snapper ] && [ -f /run/snapper-apt-pre-number ] && /usr/bin/snapper -c root create --cleanup-algorithm number -d 'APT Post-Invoke' -t post --pre-number=\$(cat /run/snapper-apt-pre-number) || true";};
EOF
  sudo chmod 644 /etc/apt/apt.conf.d/80snapper

  echo "Enabling Snapper timers..."
  sudo systemctl daemon-reload
  sudo systemctl enable snapper-boot.timer
  sudo systemctl enable --now snapper-timeline.timer
  sudo systemctl enable --now snapper-cleanup.timer

  echo "Creating initial verification snapshot..."
  sudo snapper -c root create -d "automated setup" -c number

  echo "--- Current Snapper Snapshots ---"
  sudo snapper -c root list

  echo "--- Snapper config (/etc/snapper/configs/root) ---"
  sudo grep -E '^(TIMELINE|NUMBER)_' /etc/snapper/configs/root

  if [ "$ROOT_SEPARATED" -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Root subvolume was separated. After reboot, verify with:${NC}"
    echo "  cat /proc/cmdline"
    echo "  sudo btrfs subvolume get-default /"
  fi

  # fstab mount option tuning
  FSTAB_BAK="/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
  sudo cp /etc/fstab "$FSTAB_BAK"
  echo "fstab backup created at $FSTAB_BAK"

  echo "Updating /etc/fstab..."
  awk -v root_dev="$ROOT_DEV" '
  BEGIN { OFS="\t" }
  $2 == "/.snapshots" && $0 !~ /^[[:space:]]*#/ { has_snapshots=1 }
  $3 == "btrfs" && $0 !~ /^[[:space:]]*#/ {
      len = split($4, o, ","); n=""
      for (i = 1; i <= len; i++)
          if (o[i] != "" && o[i] != "noatime" &&
              o[i] !~ /^compress(-force)?(=.*)?$/)
              n = (n ? n "," : "") o[i]
      $4 = (n ? n "," : "") "noatime,compress=zstd"
  }
  { print }
  END {
      if (!has_snapshots)
          print root_dev, "/.snapshots", "btrfs",
                "subvol=/.snapshots,defaults,noatime,compress=zstd", "0", "0"
  }' /etc/fstab |
    sudo tee /tmp/fstab >/dev/null
  sudo mv /tmp/fstab /etc/fstab

  echo "Reloading systemd manager configuration..."
  sudo systemctl daemon-reload

  echo "Applying new mount options..."
  sudo mount -a || {
    echo "mount -a failed! Restoring fstab from backup."
    sudo cp "$FSTAB_BACKUP" /etc/fstab
    sudo systemctl daemon-reload
    exit 1
  }

  echo "--- Current Btrfs Mount Status ---"
  sudo mount | grep btrfs || true
else
  echo -e "${YELLOW}Root filesystem is ${ROOT_FSTYPE}, not btrfs — skipping btrfs tuning and snapper setup.${NC}"
fi

# --- Final summary ---
echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}All automated steps complete!${NC}"
echo -e "${CYAN}==================================================${NC}"
read -rp "Press Enter to exit..."
