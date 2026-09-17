#!/bin/bash
set -euo pipefail

sudo dpkg --add-architecture i386
sudo apt update
sudo apt install -y wine winetricks winbind \
  wine32 wine64 wine64-tools wine64-preloader wine32-preloader wine-binfmt
winetricks -q corefonts cjkfonts dxvk d3dcompiler_47 d3dcompiler_43 dotnet48 vcrun2022 vcrun2013 mfc42
winecfg
