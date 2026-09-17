#!/bin/bash
set -euo pipefail

echo "Writing service..."
sudo tee "/etc/systemd/system/umount-ntfs.service" >/dev/null <<'EOF'
[Unit]
Description=Clear and Unmount all ntfs3 drives safely before shutdown
DefaultDependencies=no
After=local-fs.target
Before=umount.target shutdown.target reboot.target halt.target poweroff.target
Conflicts=shutdown.target reboot.target halt.target poweroff.target umount.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/bin/sh -c '/usr/bin/logger -t umount-ntfs "before: $(mount -t ntfs3 | wc -l) ntfs3 mounts"; /usr/bin/umount -f -l -a -t ntfs3; /usr/bin/logger -t umount-ntfs "umount exit=$?, after: $(mount -t ntfs3 | wc -l) ntfs3 mounts"'

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon and restarting service..."
sudo systemctl daemon-reload
sudo systemctl enable umount-ntfs
sudo systemctl reset-failed umount-ntfs
sudo systemctl restart umount-ntfs
echo "Success: umount-ntfs service has been configured and initiated."
sudo systemctl status umount-ntfs --no-pager
