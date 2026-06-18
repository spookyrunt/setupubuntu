#!/bin/bash
set -euo pipefail

FALLBACK_VERSION="1.4.0" # used only if the "latest" lookup fails (no internet, etc.)
DEFAULT_MOUSE_DEVICE="/dev/input/by-id/usb-HL_0000_00_00_00-01_USB_Device-if01-event-mouse"

# --- 1. Ask which evsieve version to build ---
read -rp "Which evsieve version do you want to build? [default: latest]: " VERSION_INPUT
VERSION_INPUT="${VERSION_INPUT:-latest}"

if [ "$VERSION_INPUT" = "latest" ]; then
  echo "Looking up the latest evsieve release..."
  LATEST_TAG=$(curl -s https://api.github.com/repos/KarsMulder/evsieve/releases/latest |
    grep '"tag_name":' |
    sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/')

  if [ -n "$LATEST_TAG" ]; then
    EVSIEVE_VERSION="$LATEST_TAG"
    echo "Latest version found: ${EVSIEVE_VERSION}"
  else
    echo "Could not reach GitHub to determine the latest version."
    echo "Falling back to known-good version: ${FALLBACK_VERSION}"
    EVSIEVE_VERSION="$FALLBACK_VERSION"
  fi
else
  EVSIEVE_VERSION="$VERSION_INPUT"
fi
echo "Using evsieve version: ${EVSIEVE_VERSION}"

# --- 2. Let the user pick which mouse to target ---
mapfile -t MOUSE_CANDIDATES < <(ls /dev/input/by-id/ 2>/dev/null | grep -i 'event-mouse' || true)

if [ "${#MOUSE_CANDIDATES[@]}" -eq 0 ]; then
  echo "No mouse devices found under /dev/input/by-id/."
  echo "Falling back to default: ${DEFAULT_MOUSE_DEVICE}"
  MOUSE_DEVICE="$DEFAULT_MOUSE_DEVICE"
else
  echo "Available mouse devices:"
  for i in "${!MOUSE_CANDIDATES[@]}"; do
    echo "  $((i + 1))) ${MOUSE_CANDIDATES[$i]}"
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

# --- 3. Install build dependencies ---
sudo apt install -y cargo libevdev-dev

# --- 4. Download and build evsieve ---
cd /tmp
wget "https://github.com/KarsMulder/evsieve/archive/v${EVSIEVE_VERSION}.tar.gz" -O "evsieve-${EVSIEVE_VERSION}.tar.gz"
tar -xzf "evsieve-${EVSIEVE_VERSION}.tar.gz"
cd "evsieve-${EVSIEVE_VERSION}"
cargo build --release

# --- 5. Install the binary system-wide ---
sudo cp target/release/evsieve /usr/local/bin/

# --- 6. Create the systemd service ---
sudo tee /etc/systemd/system/scroll-invert.service >/dev/null <<EOF
[Unit]
Description=Invert scroll wheel for selected mouse
After=multi-user.target

[Service]
Type=simple
ExecStart=/usr/local/bin/evsieve --input ${MOUSE_DEVICE} grab persist=reopen --map rel:wheel rel:wheel:0-x --map rel:wheel_hi_res rel:wheel_hi_res:0-x --output
Restart=on-failure
RestartSec=2

[Install]
WantedBy=multi-user.target
EOF

# --- 7. Enable and start it ---
sudo systemctl daemon-reload
sudo systemctl enable --now scroll-invert

echo "Done. Check status with: systemctl status scroll-invert"
