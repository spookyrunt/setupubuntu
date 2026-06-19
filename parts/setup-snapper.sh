#!/bin/bash
# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

# 1. Install Snapper package first
echo "Installing snapper..."
apt update && apt install -y snapper

CONFIG_NAME="root"
CONFIG_PATH="/etc/snapper/configs/$CONFIG_NAME"

# 2. Create Snapper configuration for root (if not exists)
if [ ! -f "$CONFIG_PATH" ]; then
  echo "Creating snapper configuration for root..."
  snapper -c "$CONFIG_NAME" create-config /
else
  echo "Snapper configuration for root already exists. Skipping creation."
fi

# 3. Optimize timeline limits in the configuration file
echo "Optimizing snapshot retention limits..."
sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' "$CONFIG_PATH"
sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="6"/' "$CONFIG_PATH"
sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' "$CONFIG_PATH"
sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="4"/' "$CONFIG_PATH"
sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="0"/' "$CONFIG_PATH"
sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' "$CONFIG_PATH"

# 4. Create APT hook for pre/post package-operation snapshots
HOOK_PATH="/etc/apt/apt.conf.d/80snapper"
echo "Creating APT hook for Snapper at $HOOK_PATH..."
cat <<'EOF' >"$HOOK_PATH"
DPkg::Pre-Invoke {"[ -x /usr/bin/snapper ] && snapper -c root create -d 'APT Pre-Invoke' -t pre || true";};
DPkg::Post-Invoke {"[ -x /usr/bin/snapper ] && snapper -c root create -d 'APT Post-Invoke' -t post --pre-number=$(snapper -c root list | awk '/APT Pre-Invoke/ {print $1}' | tail -n 1) || true";};
EOF
chmod 644 "$HOOK_PATH"

# 5. Create and enable systemd service for boot snapshots
echo "Creating systemd service for boot snapshots..."
SERVICE_PATH="/etc/systemd/system/snapper-boot.service"
cat <<'EOF' >"$SERVICE_PATH"
[Unit]
Description=Take Snapper Snapshot on Boot
After=local-fs.target
ConditionPathExists=/etc/snapper/configs/root

[Service]
Type=oneshot
ExecStart=/usr/bin/snapper -c root create -d "Boot Snapshot"

[Install]
WantedBy=default.target
EOF
chmod 644 "$SERVICE_PATH"

# 6. Enable and start systemd timers and boot service
echo "Enabling and starting systemd services and timers for snapper..."
systemctl daemon-reload
systemctl enable snapper-boot.service
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

# 7. Create initial verification snapshot
echo "Creating initial verification snapshot..."
snapper -c "$CONFIG_NAME" create -d "Initial automated setup"

# 8. Verify status
echo "--- Current Snapper Snapshots ---"
snapper -c "$CONFIG_NAME" list

echo "Snapper setup configuration complete. APT hook, boot snapshots, and timeline snapshots are all active."
