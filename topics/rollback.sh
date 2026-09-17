#!/bin/bash
set -euo pipefail

URL="https://raw.githubusercontent.com/spookyrunt/snapper-on-ubuntu/master/rollback.sh"
TMP="$(mktemp)"

trap 'rm -f "$TMP"' EXIT

curl -fL --retry 3 "$URL" -o "$TMP"
bash "$TMP"
