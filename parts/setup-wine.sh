#!/bin/bash
set -euo pipefail

sudo dpkg --add-architecture i386
sudo apt update -y
sudo apt install -y wine winetricks winbind \
  wine32 wine64 wine64-tools wine64-preloader wine32-preloader wine-binfmt
winecfg
