#!/bin/bash
echo "Writing service..."
sudo tee "/etc/systemd/system/umount-ntfs.service" >/dev/null <<EOF
[Unit]
Description=Clear and Unmount all ntfs3 drives safely before shutdown
DefaultDependencies=no
After=local-fs.target
Before=halt.target poweroff.target reboot.target shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecStop=/usr/bin/umount -f -l -a -t ntfs3

[Install]
WantedBy=shutdown.target reboot.target halt.target
EOF

echo "Reloading systemd daemon and restarting service..."
sudo systemctl daemon-reload
sudo systemctl enable umount-ntfs
sudo systemctl reset-failed umount-ntfs
sudo systemctl restart umount-ntfs

echo "Success: umount-ntfs service has been configured and initiated."
sudo systemctl status umount-ntfs --no-pager
