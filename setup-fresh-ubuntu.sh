#!/bin/bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}==================================================${NC}"
echo -e "${YELLOW}Fresh Ubuntu Setup: Hangul, Nerd Font, GNOME, evsieve, Neovim, Btrfs/Snapper${NC}"
echo -e "${CYAN}==================================================${NC}"

# --- Gather all interactive input up front ---
FALLBACK_EVSIEVE_VERSION="1.4.0"
DEFAULT_MOUSE_DEVICE="/dev/input/by-id/usb-HL_0000_00_00_00-01_USB_Device-if01-event-mouse"

echo -e "\n${CYAN}[evsieve] Configuration${NC}"
read -rp "Which evsieve version do you want to build? [default: latest]: " VERSION_INPUT
VERSION_INPUT="${VERSION_INPUT:-latest}"

if [ "$VERSION_INPUT" = "latest" ]; then
  echo "Looking up the latest evsieve release..."
  LATEST_TAG=$(curl -s https://api.github.com/repos/KarsMulder/evsieve/releases/latest |
    grep '"tag_name":' |
    sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/' || true)
  if [ -n "$LATEST_TAG" ]; then
    EVSIEVE_VERSION="$LATEST_TAG"
  else
    echo "Could not reach GitHub. Falling back to: ${FALLBACK_EVSIEVE_VERSION}"
    EVSIEVE_VERSION="$FALLBACK_EVSIEVE_VERSION"
  fi
else
  EVSIEVE_VERSION="$VERSION_INPUT"
fi
echo "Using evsieve version: ${EVSIEVE_VERSION}"

mapfile -t MOUSE_CANDIDATES < <(ls /dev/input/by-id/ 2>/dev/null | grep -i 'event-mouse' || true)
if [ "${#MOUSE_CANDIDATES[@]}" -eq 0 ]; then
  echo "No mouse devices found. Falling back to default: ${DEFAULT_MOUSE_DEVICE}"
  MOUSE_DEVICE="$DEFAULT_MOUSE_DEVICE"
else
  echo "Available mouse devices:"
  for i in "${!MOUSE_CANDIDATES[@]}"; do
    echo "   $((i + 1))) ${MOUSE_CANDIDATES[$i]}"
  done
  read -rp "Select a device by number (or press Enter for the default): " CHOICE
  if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#MOUSE_CANDIDATES[@]}" ]; then
    MOUSE_DEVICE="/dev/input/by-id/${MOUSE_CANDIDATES[$((CHOICE - 1))]}"
  else
    echo "No valid selection made — using default: ${DEFAULT_MOUSE_DEVICE}"
    MOUSE_DEVICE="$DEFAULT_MOUSE_DEVICE"
  fi
fi
echo "Targeting device: ${MOUSE_DEVICE}"

ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)
echo "Detected root filesystem type: ${ROOT_FSTYPE}"

echo -e "\n${GREEN}All questions answered — everything else runs unattended.${NC}"

# --- 1. System update + all packages, once (Snapper integrated) ---
echo -e "\n${CYAN}[1/8] Updating system and installing packages...${NC}"
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  ibus-hangul language-pack-ko \
  cargo libevdev-dev \
  gnome-shell-extension-manager gnome-tweaks \
  curl git ripgrep fd-find fzf sd python3 python3-pip nodejs npm \
  snapper snapper-gui

if ! command -v fd &>/dev/null; then
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

# --- 2. Hangul IME ---
echo -e "\n${CYAN}[2/8] Setting up Korean Hangul IME...${NC}"
ibus restart
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

# --- 3. Nerd Font ---
echo -e "\n${CYAN}[3/8] Installing JetBrainsMono Nerd Font...${NC}"
FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR"
curl -fLo "$FONT_DIR/JetBrainsMono.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
unzip -o "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR"
rm "$FONT_DIR/JetBrainsMono.zip"
fc-cache -f "$FONT_DIR"

# --- 4. GNOME settings ---
echo -e "\n${CYAN}[4/8] Applying GNOME settings...${NC}"
gsettings set org.gnome.desktop.interface text-scaling-factor 1.125
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'

HAS_DOCK=$(gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock" && echo "yes" || echo "no")
if [ "$HAS_DOCK" = "yes" ]; then
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT'
else
  echo -e "${YELLOW}Skipped dock-position: dash-to-dock extension not found/enabled.${NC}"
fi

# --- 5. evsieve scroll inversion ---
echo -e "\n${CYAN}[5/8] Building and installing evsieve...${NC}"
cd /tmp
wget "https://github.com/KarsMulder/evsieve/archive/v${EVSIEVE_VERSION}.tar.gz" -O "evsieve-${EVSIEVE_VERSION}.tar.gz"
tar -xzf "evsieve-${EVSIEVE_VERSION}.tar.gz"
cd "evsieve-${EVSIEVE_VERSION}"
cargo build --release
sudo cp target/release/evsieve /usr/local/bin/

sudo tee /etc/systemd/system/scroll-invert.service >/dev/null <<EOF
[Unit]
Description=Invert scroll wheel for selected mouse
After=multi-user.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/usr/local/bin/evsieve --input ${MOUSE_DEVICE} grab persist=reopen --map rel:wheel rel:wheel:0-x --map rel:wheel_hi_res rel:wheel_hi_res:0-x --output
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now scroll-invert

# --- 6. Neovim + LazyVim ---
echo -e "\n${CYAN}[6/8] Installing Neovim and LazyVim...${NC}"
NVIM_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest |
  grep "browser_download_url.*nvim-linux-x86_64.tar.gz\"" |
  cut -d '"' -f 4)
cd /tmp
curl -LO "$NVIM_URL"
tar xzf nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim
sudo mv nvim-linux-x86_64 /opt/nvim
sudo ln -sf /opt/nvim/bin/nvim /usr/local/bin/nvim
rm nvim-linux-x86_64.tar.gz
echo "Neovim $(nvim --version | head -1) installed"

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

# --- 7. Git Credential Manager (GCM) ---
echo -e "\n${CYAN}[7/8] Installing and configuring Git Credential Manager...${NC}"
GCM_DEB_URL=$(curl -s https://api.github.com/repos/git-ecosystem/git-credential-manager/releases/latest |
  grep "browser_download_url.*linux-x64.*\.deb\"" |
  cut -d '"' -f 4 || true)

if [ -z "$GCM_DEB_URL" ]; then
  echo -e "${RED}Error: Failed to fetch the GCM download URL.${NC}"
  exit 1
fi

cd /tmp
wget "$GCM_DEB_URL" -O gcm-linux-x64.deb
sudo dpkg -i gcm-linux-x64.deb || sudo apt-get install -f -y

git-credential-manager configure
git config --global credential.credentialStore secretservice
rm gcm-linux-x64.deb
echo "Git Credential Manager configured with secretservice"

git config --global core.editor "nvim"

# --- 8. Btrfs tuning + Snapper ---
echo -e "\n${CYAN}[8/8] Checking filesystem and configuring Btrfs/Snapper...${NC}"
if [ "$ROOT_FSTYPE" = "btrfs" ]; then
  echo -e "${GREEN}Root filesystem is btrfs — applying mount tuning and snapper setup.${NC}"

  # --- 8a. fstab mount option tuning (Using exact column substitution via awk) ---
  FSTAB_PATH="/etc/fstab"
  BACKUP_PATH="/etc/fstab.bak"
  sudo cp "$FSTAB_PATH" "$BACKUP_PATH"
  echo "Backup created at $BACKUP_PATH"

  TEMP_FSTAB=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ ! "$line" =~ ^[[:space:]]*# ]] && echo "$line" | awk '{print $3}' | grep -q "^btrfs$"; then
      current_options=$(echo "$line" | awk '{print $4}')
      new_options="$current_options"
      if [[ ! "$new_options" =~ "noatime" ]]; then
        new_options="${new_options},noatime"
      fi
      if [[ ! "$new_options" =~ "compress=zstd" ]]; then
        new_options="${new_options},compress=zstd"
      fi

      updated_line=$(echo "$line" | awk -v new="$new_options" 'BEGIN{OFS="\t"} {$4=new; print}')
      echo "$updated_line" >>"$TEMP_FSTAB"
    else
      echo "$line" >>"$TEMP_FSTAB"
    fi
  done <"$FSTAB_PATH"

  # Add .snapshots mount entry if not already present
  ROOT_DEV=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
  if ! grep -qE '\s+/\.snapshots\s' "$TEMP_FSTAB"; then
    echo -e "${ROOT_DEV} /.snapshots btrfs subvol=/.snapshots,defaults 0 0" >>"$TEMP_FSTAB"
  fi

  sudo mv "$TEMP_FSTAB" "$FSTAB_PATH"
  sudo chmod 644 "$FSTAB_PATH"
  echo "Reloading systemd manager configuration..."
  sudo systemctl daemon-reload
  echo "Applying new mount options..."
  sudo mount -a
  echo "--- Current Btrfs Mount Status ---"
  mount | grep btrfs || true

  # --- 8b. Snapper setup ---
  CONFIG_NAME="root"
  CONFIG_PATH="/etc/snapper/configs/$CONFIG_NAME"

  if [ ! -f "$CONFIG_PATH" ]; then
    echo "Creating snapper configuration for root..."
    sudo snapper -c "$CONFIG_NAME" create-config /
  else
    echo "Snapper configuration for root already exists. Skipping creation."
  fi

  echo "Optimizing snapshot retention limits..."
  sudo sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' "$CONFIG_PATH"
  sudo sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="6"/' "$CONFIG_PATH"
  sudo sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$CONFIG_PATH"
  sudo sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' "$CONFIG_PATH"
  sudo sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' "$CONFIG_PATH"
  sudo sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' "$CONFIG_PATH"

  HOOK_PATH="/etc/apt/apt.conf.d/80snapper"
  echo "Creating APT hook for Snapper at $HOOK_PATH..."
  sudo tee "$HOOK_PATH" >/dev/null <<'INNEREOF'
DPkg::Pre-Invoke {"[ -x /usr/bin/snapper ] && snapper -c root create -d 'APT Pre-Invoke' -t pre || true";};
DPkg::Post-Invoke {"[ -x /usr/bin/snapper ] && snapper -c root create -d 'APT Post-Invoke' -t post --pre-number=$(snapper -c root list | awk '/APT Pre-Invoke/ {print $1}' | tail -n 1) || true";};
INNEREOF
  sudo chmod 644 "$HOOK_PATH"

  SERVICE_PATH="/etc/systemd/system/snapper-boot.service"
  echo "Creating systemd service for boot snapshots..."
  sudo tee "$SERVICE_PATH" >/dev/null <<'INNEREOF'
[Unit]
Description=Take Snapper Snapshot on Boot
After=local-fs.target
ConditionPathExists=/etc/snapper/configs/root

[Service]
Type=oneshot
ExecStart=/usr/bin/snapper -c root create -d "Boot Snapshot"

[Install]
WantedBy=default.target
INNEREOF
  sudo chmod 644 "$SERVICE_PATH"

  echo "Enabling and starting systemd services and timers for snapper..."
  sudo systemctl daemon-reload
  sudo systemctl enable snapper-boot.service
  sudo systemctl enable --now snapper-timeline.timer
  sudo systemctl enable --now snapper-cleanup.timer

  echo "Creating initial verification snapshot..."
  sudo snapper -c "$CONFIG_NAME" create -d "Initial automated setup"

  echo "--- Current Snapper Snapshots ---"
  sudo snapper -c "$CONFIG_NAME" list
else
  echo -e "${YELLOW}Root filesystem is ${ROOT_FSTYPE}, not btrfs — skipping btrfs tuning and snapper setup.${NC}"
fi

# --- Final summary ---
echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}All automated steps complete!${NC}"
echo -e "${CYAN}==================================================${NC}"
read -rp "Press Enter to exit..."
