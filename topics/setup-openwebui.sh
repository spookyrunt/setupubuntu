#!/bin/bash
set -euo pipefail

mkdir -p ~/open-webui
tee ~/open-webui/docker-compose.yml <<'EOF' >/dev/null
services:
  openwebui:
    image: ghcr.io/open-webui/open-webui:main
    container_name: open-webui
    ports:
      - "3000:8080"
    volumes:
      - open-webui:/app/backend/data
    environment:
      - OLLAMA_BASE_URL=http://host.docker.internal:11434
    extra_hosts:
      - "host.docker.internal:host-gateway"
    restart: always
volumes:
  open-webui:
    name: open-webui
EOF
cd ~/open-webui/
sudo docker compose up -d
