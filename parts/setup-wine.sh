#!/bin/bash
set -euo pipefail

sudo apt install -y wine winetricks winbind
winecfg
