#!/bin/bash
set -euo pipefail

# setup vm env with qemu and kvm
sudo apt update -y
sudo apt install -y qemu-system virt-manager libvirt-daemon-system
# libvirt gives /var/lib/libvirt/images nocow by default

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'
echo
echo -e "${GREEN}Click on to launch ${RED}virt-manager${GREEN} and proceed with the installation as you would with VMware or VirtualBox.${NC}"
echo
echo -e "${RED}mount -t virtiofs src dst${NC}"
echo -e "${GREEN}or${NC}"
echo -e "${RED}Shared /path/path/Shared virtiofs defaults 0 0${GREEN} in /etc/fstab"
echo -e "allows you to use the virtiofs filesystem driver to mount the host shared folder to the guest PC.${NC}"
echo
echo -e "${GREEN}For advanced disk management without launching virt-manager, such as for mounting VHDX/QCOW2 directly, you may ${RED}apt install qemu-utils${GREEN} and run ${RED}qemu-nbd${GREEN} or run ${RED}qemu-img${GREEN} for editing image files.${NC}"
