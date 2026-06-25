#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Elevating privileges (sudo)..."
  exec sudo bash "$0" "$@"
fi

#################################################
# PART 1: Separate root subvolume from snapshot tree
# This must run BEFORE snapper starts taking automated
# snapshots, so the root we end up on is a clean,
# independent subvolume rather than something nested
# under .snapshots.
#################################################

FSTAB_PATH="/etc/fstab"
FSTAB_BACKUP="/etc/fstab.bak.$(date +%Y%m%d%H%M%S)"

cp "$FSTAB_PATH" "$FSTAB_BACKUP"
echo "fstab backup created at $FSTAB_BACKUP"

ROOT_DEV=$(findmnt -no SOURCE / | sed 's/\[.*\]//')
echo "Root device: $ROOT_DEV"

mkdir -p /mnt/topsetup
mount -o subvolid=5 "$ROOT_DEV" /mnt/topsetup

CURRENT_DEFAULT_PATH=$(btrfs subvolume get-default / | awk '{print $NF}')
NEW_ROOT_NAME="@active_root"

if [[ "$CURRENT_DEFAULT_PATH" == *".snapshots/"* ]]; then
  echo "Current root is inside a snapshot path. Separating it."
  SRC_PATH="/mnt/topsetup/${CURRENT_DEFAULT_PATH#<FS_TREE>/}"

  if [ ! -d "/mnt/topsetup/${NEW_ROOT_NAME}" ]; then
    btrfs subvolume snapshot "$SRC_PATH" "/mnt/topsetup/${NEW_ROOT_NAME}"
  else
    echo "${NEW_ROOT_NAME} already exists, skipping creation"
  fi

  NEW_ID=$(btrfs subvolume list /mnt/topsetup | grep "path ${NEW_ROOT_NAME}$" | awk '{print $2}')
  btrfs subvolume set-default "$NEW_ID" /mnt/topsetup
  echo "Default subvolume set to ${NEW_ROOT_NAME} (ID ${NEW_ID})."
  ROOT_SEPARATED=1
else
  echo "Already an independent subvolume structure. No change."
  ROOT_SEPARATED=0
fi

umount /mnt/topsetup

#################################################
# PART 2: Normalize fstab options (noatime, compress=zstd)
#################################################

TEMP_FSTAB=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
  if [[ ! "$line" =~ ^[[:space:]]*# ]] && echo "$line" | awk '{print $3}' | grep -q "^btrfs$"; then
    current_options=$(echo "$line" | awk '{print $4}')
    new_options="$current_options"

    if [[ ! "$new_options" =~ "noatime" ]]; then
      new_options="${new_options},noatime"
    fi

    if [[ "$new_options" =~ compress=[a-z0-9:]+ ]]; then
      new_options=$(echo "$new_options" | sed -E 's/compress=[a-z0-9:]+/compress=zstd/')
    else
      new_options="${new_options},compress=zstd"
    fi

    updated_line=$(echo "$line" | awk -v new="$new_options" 'BEGIN{OFS="\t"} {$4=new; print}')
    echo "$updated_line" >>"$TEMP_FSTAB"
  else
    echo "$line" >>"$TEMP_FSTAB"
  fi
done <"$FSTAB_PATH"

mv "$TEMP_FSTAB" "$FSTAB_PATH"
chmod 644 "$FSTAB_PATH"

echo "Reloading systemd manager configuration..."
systemctl daemon-reload

echo "Applying new mount options..."
if ! mount -a; then
  echo "mount -a failed! Restoring fstab from backup."
  cp "$FSTAB_BACKUP" "$FSTAB_PATH"
  systemctl daemon-reload
  exit 1
fi

echo "--- Current Btrfs Mount Status ---"
mount | grep btrfs

#################################################
# PART 3: Install and configure snapper + grub-btrfs
# Runs AFTER root separation, so automated snapshots
# accumulate on the clean root, not the old snapshot tree.
#################################################

echo "Installing snapper and build dependencies..."
apt update
apt install -y snapper git make inotify-tools gawk

# Ubuntu's default /usr/bin/awk is mawk, which does not support the \s
# regex class. grub-btrfs's snapshot-detection script relies on \s when
# parsing `btrfs subvolume show` output to find the root subvolume UUID,
# so under mawk it silently fails with "UUID of the root subvolume is
# not available". Switch the system default to gawk to avoid this.
update-alternatives --set awk /usr/bin/gawk

# grub-btrfs is NOT available in Ubuntu/Debian's apt repositories
# (confirmed: only packaged for Arch/Gentoo). It must be built from
# source. Skip the build if it's already installed.
if command -v grub-btrfsd >/dev/null && [ -f /etc/systemd/system/grub-btrfsd.service ]; then
  echo "grub-btrfs already installed. Skipping build."
else
  echo "Installing grub-btrfs from source (not packaged for Ubuntu)..."
  GRUB_BTRFS_SRC="/tmp/grub-btrfs"
  rm -rf "$GRUB_BTRFS_SRC"
  git clone https://github.com/Antynea/grub-btrfs.git "$GRUB_BTRFS_SRC"
  (cd "$GRUB_BTRFS_SRC" && make install)
fi

# GRUB_BTRFS_LIMIT defaults to 50, which is too low once snapper has
# accumulated more snapshots than that (newest ones silently get cut
# from grub.cfg detection). Raise it well above the snapper retention
# totals configured below.
# NOTE: GRUB_BTRFS_LIMIT="0" does NOT mean unlimited — the underlying
# script breaks out of its loop as soon as the counter hits <= 0, so
# 0 means "show nothing". Use a large positive number instead.
GRUB_BTRFS_CONFIG="/etc/default/grub-btrfs/config"
if [ -f "$GRUB_BTRFS_CONFIG" ]; then
  if grep -q "^GRUB_BTRFS_LIMIT=" "$GRUB_BTRFS_CONFIG"; then
    sed -i 's/^GRUB_BTRFS_LIMIT=.*/GRUB_BTRFS_LIMIT="300"/' "$GRUB_BTRFS_CONFIG"
  elif grep -q "^#GRUB_BTRFS_LIMIT=" "$GRUB_BTRFS_CONFIG"; then
    sed -i 's/^#GRUB_BTRFS_LIMIT=.*/GRUB_BTRFS_LIMIT="300"/' "$GRUB_BTRFS_CONFIG"
  else
    echo 'GRUB_BTRFS_LIMIT="300"' >>"$GRUB_BTRFS_CONFIG"
  fi
fi

CONFIG_NAME="root"
CONFIG_PATH="/etc/snapper/configs/$CONFIG_NAME"

if [ ! -f "$CONFIG_PATH" ]; then
  echo "Creating snapper configuration for root..."
  snapper -c "$CONFIG_NAME" create-config /
else
  echo "Snapper configuration for root already exists. Skipping creation."
fi

CONFIG_BACKUP="${CONFIG_PATH}.bak.$(date +%Y%m%d%H%M%S)"
cp "$CONFIG_PATH" "$CONFIG_BACKUP"
echo "Snapper config backed up to $CONFIG_BACKUP"

set_config_value() {
  local key="$1"
  local value="$2"
  if grep -q "^${key}=" "$CONFIG_PATH"; then
    sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$CONFIG_PATH"
  else
    echo "${key}=\"${value}\"" >>"$CONFIG_PATH"
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
cat <<EOF >"$HOOK_PATH"
DPkg::Pre-Invoke {"[ -x /usr/bin/snapper ] && /usr/bin/snapper -c root create --print-number -t pre -d 'APT Pre-Invoke' > ${STATE_FILE} 2>/dev/null || true";};
DPkg::Post-Invoke {"[ -x /usr/bin/snapper ] && [ -f ${STATE_FILE} ] && /usr/bin/snapper -c root create -d 'APT Post-Invoke' -t post --pre-number=\$(cat ${STATE_FILE}) || true";};
EOF
chmod 644 "$HOOK_PATH"

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

echo "Enabling services and timers..."
systemctl daemon-reload
systemctl enable snapper-boot.service
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer

if systemctl list-unit-files | grep -q grub-btrfsd.service; then
  systemctl enable --now grub-btrfsd.service
else
  echo "Warning: grub-btrfsd.service not found. Check grub-btrfs installation."
fi

echo "Creating initial verification snapshot..."
snapper -c "$CONFIG_NAME" create -d "Initial automated setup"

#################################################
# PART 4: Single final grub regeneration
# (Only done once here, not separately in each part.)
#################################################

if command -v update-grub >/dev/null; then
  echo "Regenerating grub config..."
  update-grub
fi

#################################################
# PART 5: Final verification
#################################################

echo "--- Current Snapper Snapshots ---"
snapper -c "$CONFIG_NAME" list

echo "--- Snapper config ($CONFIG_PATH) ---"
grep -E '^(TIMELINE|NUMBER)_' "$CONFIG_PATH"

if [ "$ROOT_SEPARATED" -eq 1 ]; then
  echo ""
  echo "Root subvolume was separated. After reboot, verify with:"
  echo "  cat /proc/cmdline"
  echo "  sudo btrfs subvolume get-default /"
fi

echo "Setup complete: root separation, fstab normalization, snapper, and grub-btrfs auto-sync are all active."
