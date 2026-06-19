#!/bin/bash

# Ensure the script is run with root privileges
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

FSTAB_PATH="/etc/fstab"
BACKUP_PATH="/etc/fstab.bak"

# Create a backup of the original fstab file
cp "$FSTAB_PATH" "$BACKUP_PATH"
echo "Backup created at $BACKUP_PATH"

# Process fstab file line by line
# Updates btrfs mount options to include noatime and compress=zstd if not already present
TEMP_FSTAB=$(mktemp)

while IFS= read -r line || [ -n "$line" ]; do
  # Check if the line is not a comment and contains btrfs filesystem type
  if [[ ! "$line" =~ ^[[:space:]]*# ]] && echo "$line" | awk '{print $3}' | grep -q "^btrfs$"; then
    # Extract the options column (4th column)
    current_options=$(echo "$line" | awk '{print $4}')
    new_options="$current_options"

    # Append noatime if missing
    if [[ ! "$new_options" =~ "noatime" ]]; then
      new_options="${new_options},noatime"
    fi

    # Append compress=zstd if missing (handles variations like compress=zstd:3)
    if [[ ! "$new_options" =~ "compress=zstd" ]]; then
      new_options="${new_options},compress=zstd"
    fi

    # Replace the old options with the new options in the line
    updated_line=$(echo "$line" | awk -v new="$new_options" 'BEGIN{OFS="\t"} {$4=new; print}')
    echo "$updated_line" >>"$TEMP_FSTAB"
  else
    echo "$line" >>"$TEMP_FSTAB"
  fi
done <"$FSTAB_PATH"

# Apply the changes
mv "$TEMP_FSTAB" "$FSTAB_PATH"
chmod 644 "$FSTAB_PATH"

# Test and Apply Changes Safely
echo "Reloading systemd manager configuration..."
systemctl daemon-reload

echo "Applying new mount options..."
# Mount all filesystems listed in fstab, remounting already mounted ones
mount -a

# Display active Btrfs mount status
echo "--- Current Btrfs Mount Status ---"
mount | grep btrfs

echo "Done."
