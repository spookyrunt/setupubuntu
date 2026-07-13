#!/bin/bash
set -euo pipefail

sudo apt update -y
sudo apt install -y wine winetricks winbind
winecfg
