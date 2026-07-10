#!/bin/bash
set -euo pipefail

if [ "$EUID" -ne 0 ]; then
  echo "Elevating privileges (sudo)..."
  exec sudo bash "$0" "$@"
fi

# Get the actual user even when running with sudo
TARGET_USER="${SUDO_USER:-$USER}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
  echo "Cannot verify the actual user. Please run with SUDO_USER set."
  exit 1
fi
echo "Target user: $TARGET_USER"

# Interactive input for the custom Samba username with a default fallback
echo "=========================================="
read -p "Enter the Samba username to create/configure [default: Scanner]: " SAMBA_USER
SAMBA_USER="${SAMBA_USER:-Scanner}"
echo "Samba user set to: $SAMBA_USER"
echo "=========================================="

# 1. Installation
apt update -y
apt install -y samba nautilus-share smbclient

# 2. Restart nautilus to update usershare menu (ignore failure)
sudo -u "$TARGET_USER" nautilus -q || true

# 3. Create usershares directory
mkdir -p /var/lib/samba/usershares

# 4. Add target user to sambashare group
usermod -aG sambashare "$TARGET_USER"

# 5. Configure usershare max shares in smb.conf (avoid duplication)
SMB_CONF="/etc/samba/smb.conf"
if ! grep -q "^\s*usershare max shares" "$SMB_CONF"; then
  sed -i '/^\[global\]/a\   usershare max shares = 100' "$SMB_CONF"
  echo "Added 'usershare max shares = 100' to smb.conf"
else
  echo "Already configured (usershare max shares)"
fi

# 6. Create custom Samba account (no-login account)
if id "$SAMBA_USER" &>/dev/null; then
  echo "Account '$SAMBA_USER' already exists"
else
  useradd -M -s /usr/sbin/nologin "$SAMBA_USER"
  echo "Account '$SAMBA_USER' creation complete"
fi

# 7. Set Samba password for the custom user (interactive)
echo "Setting Samba password for $SAMBA_USER:"
if pdbedit -L 2>/dev/null | grep -q "^$SAMBA_USER:"; then
  smbpasswd "$SAMBA_USER"
else
  smbpasswd -a "$SAMBA_USER"
fi

# 8. Add custom user to target user's group for home directory subdirectory share access
usermod -aG "$TARGET_USER" "$SAMBA_USER"

# 9. Grant pass-through permission to mount directory
MEDIA_DIR="/run/media/$TARGET_USER"
if [ -d "$MEDIA_DIR" ]; then
  chmod o+x "$MEDIA_DIR"
  echo "Granted pass-through permission (o+x) to $MEDIA_DIR"
else
  echo "Note: $MEDIA_DIR does not exist yet (before mounting external drive)"
fi

# 10. Restart services
systemctl restart smbd nmbd

# 11. Verify configuration
echo "----- testparm -s -----"
testparm -s 2>/dev/null

echo "Note: smbclient maybe useful."
echo
echo "=========================================="
echo "IMPORTANT: Please log out and log back in"
echo "(or reboot) for '$TARGET_USER' to gain"
echo "sambashare group permissions."
echo "=========================================="
echo
echo "Done."
