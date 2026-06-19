#!/bin/bash
set -euo pipefail

SERVICE_PATH="/etc/systemd/system/scroll-invert.service"
EVSIEVE_BIN="/usr/local/bin/evsieve"
DEFAULT_MOUSE_DEVICE="/dev/input/by-id/usb-KG3618X_H2_V1_YX-01_USB_Device-if01-event-mouse"
FALLBACK_VERSION="1.4.0"

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

if [ ! -f "${EVSIEVE_BIN}" ]; then
  echo "Warning: ${EVSIEVE_BIN} not found. Initiating dynamic version lookup and build process..."

  read -rp "Which evsieve version do you want to build? [default: latest]: " VERSION_INPUT
  VERSION_INPUT="${VERSION_INPUT:-latest}"

  if [ "$VERSION_INPUT" = "latest" ]; then
    echo "Looking up the latest evsieve release..."
    LATEST_TAG=$(curl -s https://api.github.com/repos/KarsMulder/evsieve/releases/latest |
      grep '"tag_name":' |
      sed -E 's/.*"tag_name": *"v?([^"]+)".*/\1/' || true)

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

  if [ -f "/tmp/evsieve-${EVSIEVE_VERSION}/target/release/evsieve" ]; then
    sudo cp "/tmp/evsieve-${EVSIEVE_VERSION}/target/release/evsieve" "${EVSIEVE_BIN}"
  else
    echo "Error: evsieve binary is missing entirely. Please run the full compilation process for version ${EVSIEVE_VERSION}." >&2
    exit 1
  fi
fi

echo "Updating Systemd service specification..."
sudo tee "${SERVICE_PATH}" >/dev/null <<EOF
[Unit]
Description=Invert scroll wheel for selected mouse
After=multi-user.target
StartLimitIntervalSec=0

[Service]
Type=simple
ExecStart=${EVSIEVE_BIN} --input ${MOUSE_DEVICE} grab persist=reopen --map rel:wheel rel:wheel:0-x --map rel:wheel_hi_res rel:wheel_hi_res:0-x --output
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon and restarting service..."
sudo systemctl daemon-reload
sudo systemctl enable scroll-invert
sudo systemctl reset-failed scroll-invert
sudo systemctl restart scroll-invert

echo "Success: scroll-invert service has been reconfigured and initiated."
sudo systemctl status scroll-invert --no-pager
