#!/bin/bash
set -euo pipefail

sudo apt purge 'apport*'
sudo apt autoremove --purge -y
sudo rm -rf /var/crash/*
