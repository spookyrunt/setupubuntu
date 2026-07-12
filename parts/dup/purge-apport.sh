#!/bin/bash
set -euo pipefail

# [ -f "/etc/default/apport" ] && sudo sed -i 's/enabled=1/enabled=0/' /etc/default/apport
sudo apt purge 'apport*'
sudo apt autoremove --purge -y
sudo rm -rf /var/crash/*
