#!/bin/bash
set -euo pipefail

SERVICE_PATH="/etc/systemd/system/scroll-invert.service"
EVSIEVE_BIN="/usr/local/bin/evsieve"
DEFAULT_MOUSE_DEVICE="/dev/input/by-id/usb-HL_0000_00_00_00-01_USB_Device-if01-event-mouse"
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

VENDOR_ID=$(udevadm info --query=property --name="${MOUSE_DEVICE}" | grep 'ID_VENDOR_ID=' | cut -d= -f2 || true)
MODEL_ID=$(udevadm info --query=property --name="${MOUSE_DEVICE}" | grep 'ID_MODEL_ID=' | cut -d= -f2 || true)

echo "Targeting device: ${MOUSE_DEVICE}"

# Installation — skip build if evsieve is already present
if [ -f "$EVSIEVE_BIN" ]; then
  echo "evsieve is already installed. Skipping download and compilation."
else
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

  wget "https://github.com/KarsMulder/evsieve/archive/v${EVSIEVE_VERSION}.tar.gz" -O "/tmp/evsieve-${EVSIEVE_VERSION}.tar.gz"
  tar -xzf "/tmp/evsieve-${EVSIEVE_VERSION}.tar.gz" -C /tmp
  cargo build --release --manifest-path="/tmp/evsieve-${EVSIEVE_VERSION}/Cargo.toml"
  sudo cp "/tmp/evsieve-${EVSIEVE_VERSION}/target/release/evsieve" "$EVSIEVE_BIN"
fi

sudo tee "$SERVICE_PATH" >/dev/null <<EOF
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