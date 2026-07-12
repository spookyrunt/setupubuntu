#!/bin/bash
set -euo pipefail

cd
nix profile install nixpkgs#lynis
sudo ln -s "$HOME/.nix-profile/bin/lynis" /usr/local/bin/lynis || true
sudo lynis audit system

sudo apt update -y
sudo apt install -y firejail
#sudo firecfg

sudo apt install -y fail2ban
sudo systemctl enable --now fail2ban

sudo apt install -y clamav clamav-daemon
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
sudo tail -n 50 /var/log/clamav/freshclam.log
# sudo tail --follow /var/log/clamav/freshclam.log
clamscan

sudo apt install -y ansible
[ -d ~/ansible-os-hardening ] ||
  git clone https://github.com/dev-sec/ansible-os-hardening.git ~/ansible-os-hardening

cd ~/ansible-os-hardening
tee playbook.yml <<<"- hosts: localhost
  connection: local
  become: yes
  vars:
    os_security_suid_sgid_whitelist:
      - /usr/lib/polkit-1/polkit-agent-helper-1
    os_chmod_home_folders: false
    hidepid_option: "0"
    sysctl_overwrite:
      net.ipv4.ip_forward: 1
  roles:
    - roles/os_hardening"

sudo ansible-galaxy collection install ansible.posix
sudo ansible-playbook playbook.yml
