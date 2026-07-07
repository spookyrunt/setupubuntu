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

# --- 1. System update + all packages, once (Snapper integrated) ---
# Runs first so curl, git, etc. are available for
# everything below, before any interactive prompts.
echo -e "\n${CYAN}[1/8] Updating system and installing packages...${NC}"
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y \
  ibus-hangul language-pack-ko gedit \
  gnome-shell-extension-manager gnome-tweaks \
  cargo libevdev-dev \
  xclip xsel wl-clipboard \
  curl git unzip build-essential \
  ripgrep fd-find fzf sd \
  python3 python3-pip nodejs npm \
  snapper btrfs-assistant # btrfs-progs btrfs-heatmap btrfs-compsize

if ! command -v fd &>/dev/null; then
  sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
fi

ROOT_FSTYPE=$(findmnt -n -o FSTYPE /)
echo "Detected root filesystem type: ${ROOT_FSTYPE}"

# --- 2. Hangul IME ---
echo -e "\n${CYAN}[2/8] Setting up Korean Hangul IME...${NC}"
ibus restart
gsettings set org.gnome.desktop.input-sources sources "[('ibus', 'hangul')]"

# --- 3. Nerd Font ---
echo -e "\n${CYAN}[3/8] Installing JetBrainsMono Nerd Font...${NC}"
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

# --- 4. GNOME settings ---
echo -e "\n${CYAN}[4/8] Applying GNOME settings...${NC}"
gsettings set org.gnome.desktop.interface text-scaling-factor 1.10
gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrainsMono Nerd Font 12'
gsettings set org.gnome.SessionManager logout-prompt false

HAS_DOCK=$(gsettings list-schemas | grep -q "org.gnome.shell.extensions.dash-to-dock" && echo "yes" || echo "no")
if [ "$HAS_DOCK" = "yes" ]; then
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'RIGHT'
else
  echo -e "${YELLOW}Skipped dock-position: dash-to-dock extension not found/enabled.${NC}"
fi

# --- 5. Purge Apport and GNOME Text Editor ---
[ -f "/etc/default/apport" ] && sudo sed -i 's/enabled=1/enabled=0/' /etc/default/apport
sudo apt purge 'apport*' gnome-text-editor
sudo apt autoremove --purge -y
sudo rm -rf /var/crash/*

# --- 6. evsieve scroll inversion ---
echo -e "\n${CYAN}[5/8] Building and installing evsieve...${NC}"

for _ in 1; do
  read -rp "Which evsieve version do you want to build? [default: latest, 's' or 'skip' to skip]: " VERSION_INPUT
  VERSION_INPUT="${VERSION_INPUT:-latest}"

  if [ "$VERSION_INPUT" = "s" ] || [ "$VERSION_INPUT" = "skip" ]; then
    echo -e "${YELLOW}Skipping evsieve/scroll-invert setup as requested by user.${NC}"
    break
  fi

  LATEST_TAG=$(curl -s https://api.github.com/repos/KarsMulder/evsieve/releases/latest |
    grep '"tag_name":' |
    sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/' || true)

  if [ "$VERSION_INPUT" != "latest" ]; then
    EVSIEVE_VERSION="$VERSION_INPUT"
  elif [ -n "$LATEST_TAG" ]; then
    EVSIEVE_VERSION="$LATEST_TAG"
  else
    FALLBACK_EVSIEVE_VERSION="1.4.0"
    echo "Could not reach GitHub. Falling back to: ${FALLBACK_EVSIEVE_VERSION}"
    EVSIEVE_VERSION="$FALLBACK_EVSIEVE_VERSION"
  fi

  echo "Using evsieve version: ${EVSIEVE_VERSION}"

  # Get device
  DEFAULT_MOUSE_DEVICE="/dev/input/by-id/usb-HL_0000_00_00_00-01_USB_Device-if01-event-mouse"
  MOUSE_DEVICE=""
  VENDOR_ID=""
  MODEL_ID=""
  mapfile -t MOUSE_CANDIDATES < <(ls /dev/input/by-id/ 2>/dev/null | grep -i 'event-mouse' || true)
  if [ "${#MOUSE_CANDIDATES[@]}" -eq 0 ]; then
    echo "No mouse devices found. Falling back to default: ${DEFAULT_MOUSE_DEVICE}"
    MOUSE_DEVICE="$DEFAULT_MOUSE_DEVICE"
  else
    echo "Available mouse devices:"
    for i in "${!MOUSE_CANDIDATES[@]}"; do
      echo "   $((i + 1))) ${MOUSE_CANDIDATES[$i]}"
    done

    read -rp "Select a device by number, press Enter for the default: " CHOICE

    if [[ "$CHOICE" =~ ^[0-9]+$ ]] && [ "$CHOICE" -ge 1 ] && [ "$CHOICE" -le "${#MOUSE_CANDIDATES[@]}" ]; then
      MOUSE_DEVICE="/dev/input/by-id/${MOUSE_CANDIDATES[$((CHOICE - 1))]}"
    else
      echo "No valid selection made — using default: ${DEFAULT_MOUSE_DEVICE}"
      MOUSE_DEVICE="$DEFAULT_MOUSE_DEVICE"
    fi
  fi

  # Get device ID
  # If the resolved device (selected or default) doesn't actually exist,
  # don't fail the whole step — just skip scroll-invert.
  if [ ! -e "$MOUSE_DEVICE" ]; then
    echo -e "${YELLOW}Warning: ${MOUSE_DEVICE} does not exist on this machine.${NC}"
  else
    VENDOR_ID=$(udevadm info --query=property --name="${MOUSE_DEVICE}" | grep 'ID_VENDOR_ID=' | cut -d= -f2 || true)
    MODEL_ID=$(udevadm info --query=property --name="${MOUSE_DEVICE}" | grep 'ID_MODEL_ID=' | cut -d= -f2 || true)
    if [ -z "$VENDOR_ID" ] || [ -z "$MODEL_ID" ]; then
      echo -e "${YELLOW}Warning: could not read vendor/model ID for ${MOUSE_DEVICE}.${NC}"
    else
      echo "Targeting device: ${MOUSE_DEVICE}"
    fi
  fi

  # Installation
  if [ -z "$VENDOR_ID" ] || [ -z "$MODEL_ID" ]; then
    echo -e "${YELLOW}Skipping evsieve/scroll-invert setup.${NC}"
  else
    EVSIEVE_BIN="/usr/local/bin/evsieve"
    INSTALLED_VERSION=$("$EVSIEVE_BIN" --version 2>/dev/null | awk '{print $2}' || true)
    if [ "$INSTALLED_VERSION" = "$EVSIEVE_VERSION" ]; then
      echo "evsieve version ${EVSIEVE_VERSION} is already installed. Skipping download and compilation."
    else
      wget "https://github.com/KarsMulder/evsieve/archive/v${EVSIEVE_VERSION}.tar.gz" -O "/tmp/evsieve-${EVSIEVE_VERSION}.tar.gz"
      tar -xzf "/tmp/evsieve-${EVSIEVE_VERSION}.tar.gz" -C /tmp
      cargo build --release --manifest-path="/tmp/evsieve-${EVSIEVE_VERSION}/Cargo.toml"
      sudo cp "/tmp/evsieve-${EVSIEVE_VERSION}/target/release/evsieve" /usr/local/bin/
    fi

    sudo tee /etc/systemd/system/scroll-invert.service >/dev/null <<EOF
[Unit]
Description=Invert scroll wheel for selected mouse
After=multi-user.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=/bin/sh -c '\\
  TARGET_PATH=\$(find /dev/input/by-id/ -type l -name "*event-mouse*" | xargs -r -I {} sh -c "\\
    udevadm info --query=property --name=\"{}\" | grep -q \"ID_VENDOR_ID=${VENDOR_ID}\" && \\
    udevadm info --query=property --name=\"{}\" | grep -q \"ID_MODEL_ID=${MODEL_ID}\" && \\
    echo \"{}\" \\
  " 2>/dev/null | head -n 1); \\
  exec ${EVSIEVE_BIN} \\
    --input "\$TARGET_PATH" grab persist=exit \\
    --map rel:wheel rel:wheel:0-x \\
    --map rel:wheel_hi_res rel:wheel_hi_res:0-x \\
    --map rel:hwheel rel:hwheel:0-x \\
    --map rel:hwheel_hi_res rel:hwheel_hi_res:0-x \\
    --output \\
'
Restart=always
RestartSec=1

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now scroll-invert
  fi

done

# --- 7. Neovim + LazyVim ---
echo -e "\n${CYAN}[6/8] Installing Neovim and LazyVim...${NC}"

for _ in 1; do
  NVIM_LATEST_TAG=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest |
    grep '"tag_name":' |
    sed -E 's/.*"tag_name": *"([^"]+)".*/\1/' || true)
  CURRENT_VERSION=$(nvim --version 2>/dev/null | head -n 1 | awk '{print $2}' || true)
  if [ -n "$NVIM_LATEST_TAG" ] && [ "$CURRENT_VERSION" = "$NVIM_LATEST_TAG" ]; then
    echo "Neovim is already installed and up to date (${CURRENT_VERSION}). Skipping."
    break
  fi

  NVIM_URL=$(curl -s https://api.github.com/repos/neovim/neovim/releases/latest |
    grep "browser_download_url.*nvim-linux-x86_64.tar.gz\"" |
    cut -d '"' -f 4)
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

# --- 8. Git Credential Manager (GCM) ---
echo -e "\n${CYAN}[7/8] Installing and configuring Git Credential Manager...${NC}"

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

git config --global core.editor "nvim"

# --- 9. Btrfs root separation + fstab tuning + Snapper ---
echo -e "\n${CYAN}[8/8] Checking filesystem and configuring Btrfs/Snapper...${NC}"
if [ "$ROOT_FSTYPE" = "btrfs" ]; then
  echo -e "${GREEN}Root filesystem is btrfs — separating root, tuning fstab, and configuring snapper.${NC}"

  # --- 9a. Separate root subvolume from snapshot tree ---
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

  # --- 9b. fstab mount option tuning ---
  FSTAB_PATH="/etc/fstab"
  FSTAB_BACKUP="/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"
  sudo cp "$FSTAB_PATH" "$FSTAB_BACKUP"
  echo "fstab backup created at $FSTAB_BACKUP"

  TEMP_FSTAB=$(mktemp)

  while IFS= read -r line || [ -n "$line" ]; do
    if [[ ! "$line" =~ ^[[:space:]]*# ]] && echo "$line" | awk '{print $3}' | grep -q "^btrfs$"; then
      current_options=$(echo "$line" | awk '{print $4}')
      new_options="$current_options"

      if [[ "$new_options" != *noatime* ]]; then
        new_options="${new_options:+$new_options,}noatime"
      fi

      if [[ "$new_options" == *compress-force=* ]]; then
        new_options=$(echo "$new_options" | sed -E 's/compress-force=[a-z0-9:]+/compress-force=zstd/')
      elif [[ "$new_options" == *compress=* ]]; then
        new_options=$(echo "$new_options" | sed -E 's/compress=[a-z0-9:]+/compress=zstd/')
      else
        new_options="${new_options:+$new_options,}compress=zstd"
      fi

      updated_line="${line/"$current_options"/"$new_options"}"
      echo "$updated_line" >>"$TEMP_FSTAB"
    else
      echo "$line" >>"$TEMP_FSTAB"
    fi
  done <"$FSTAB_PATH"

  if ! grep -qE '\s+/\.snapshots\s' "$TEMP_FSTAB"; then
    echo -e "${ROOT_DEV}\t/.snapshots\tbtrfs\tsubvol=/.snapshots,defaults,noatime,compress=zstd\t0\t0" >>"$TEMP_FSTAB"
  fi

  sudo mv "$TEMP_FSTAB" "$FSTAB_PATH"
  sudo chmod 644 "$FSTAB_PATH"

  echo "Reloading systemd manager configuration..."
  sudo systemctl daemon-reload

  echo "Applying new mount options..."
  if ! sudo mount -a; then
    echo "mount -a failed! Restoring fstab from backup."
    sudo cp "$FSTAB_BACKUP" "$FSTAB_PATH"
    sudo systemctl daemon-reload
    exit 1
  fi

  echo "--- Current Btrfs Mount Status ---"
  mount | grep btrfs || true

  CONFIG_NAME="root"
  CONFIG_PATH="/etc/snapper/configs/$CONFIG_NAME"

  if [ ! -f "$CONFIG_PATH" ]; then
    echo "Creating snapper configuration for root..."
    sudo snapper -c "$CONFIG_NAME" create-config /
  else
    echo "Snapper configuration for root already exists. Skipping creation."
  fi

  CONFIG_BACKUP="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
  sudo cp "$CONFIG_PATH" "$CONFIG_BACKUP"
  echo "Snapper config backed up to $CONFIG_BACKUP"

  set_config_value() {
    local key="$1"
    local value="$2"
    if sudo grep -q "^${key}=" "$CONFIG_PATH"; then
      sudo sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONFIG_PATH"
    else
      echo "${key}=\"${value}\"" | sudo tee -a "$CONFIG_PATH" >/dev/null
    fi
  }

  echo "Configuring timeline snapshot retention..."
  set_config_value "TIMELINE_CREATE" "yes"
  set_config_value "TIMELINE_LIMIT_HOURLY" "6"
  set_config_value "TIMELINE_LIMIT_DAILY" "7"
  set_config_value "TIMELINE_LIMIT_WEEKLY" "4"
  set_config_value "TIMELINE_LIMIT_MONTHLY" "0"
  set_config_value "TIMELINE_LIMIT_YEARLY" "0"

  echo "Configuring number-based cleanup for apt/boot snapshots..."
  set_config_value "NUMBER_CLEANUP" "yes"
  set_config_value "NUMBER_LIMIT" "50"
  set_config_value "NUMBER_LIMIT_IMPORTANT" "10"

  HOOK_PATH="/etc/apt/apt.conf.d/80snapper"
  STATE_FILE="/run/snapper-apt-pre-number"
  echo "Creating APT hook for Snapper at $HOOK_PATH..."
  sudo tee "$HOOK_PATH" >/dev/null <<EOF
DPkg::Pre-Invoke {"[ -x /usr/bin/snapper ] && /usr/bin/snapper -c root create --print-number -t pre -d 'APT Pre-Invoke' > ${STATE_FILE} 2>/dev/null || true";};
DPkg::Post-Invoke {"[ -x /usr/bin/snapper ] && [ -f ${STATE_FILE} ] && /usr/bin/snapper -c root create -d 'APT Post-Invoke' -t post --pre-number=\$(cat ${STATE_FILE}) || true";};
EOF
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

  echo "Enabling services and timers..."
  sudo systemctl daemon-reload
  sudo systemctl enable snapper-boot.service
  sudo systemctl enable --now snapper-timeline.timer
  sudo systemctl enable --now snapper-cleanup.timer

  echo "Creating initial verification snapshot..."
  sudo snapper -c "$CONFIG_NAME" create -d "Initial automated setup"

  echo "--- Current Snapper Snapshots ---"
  sudo snapper -c "$CONFIG_NAME" list

  echo "--- Snapper config ($CONFIG_PATH) ---"
  sudo grep -E '^(TIMELINE|NUMBER)_' "$CONFIG_PATH"

  if [ "$ROOT_SEPARATED" -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Root subvolume was separated. After reboot, verify with:${NC}"
    echo "  cat /proc/cmdline"
    echo "  sudo btrfs subvolume get-default /"
  fi
else
  echo -e "${YELLOW}Root filesystem is ${ROOT_FSTYPE}, not btrfs — skipping btrfs tuning and snapper setup.${NC}"
fi

# --- Final summary ---
echo -e "\n${CYAN}==================================================${NC}"
echo -e "${GREEN}All automated steps complete!${NC}"
echo -e "${CYAN}==================================================${NC}"
read -rp "Press Enter to exit..."
