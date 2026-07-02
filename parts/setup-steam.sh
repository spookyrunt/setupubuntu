#!/bin/bash
set -euo pipefail

sudo dpkg --print-foreign-architectures
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install steam-install
# PROTON_LOG=1 steam
