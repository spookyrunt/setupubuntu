#!/bin/bash
set -euo pipefail

cd
nix profile install nixpkgs#lynis
sudo ln -s "$HOME/.nix-profile/bin/lynis" /usr/local/bin/lynis
sudo lynis audit system

sudo apt install firejail
sudo firecfg

sudo apt install fail2ban
sudo systemctl enable --now fail2ban

sudo apt install clamav clamav-daemon
sudo systemctl stop clamav-freshclam
sudo freshclam
sudo systemctl start clamav-freshclam
sudo tail -n 50 /var/log/clamav/freshclam.log
# sudo tail --follow /var/log/clamav/freshclam.log
clamscan

sudo apt install ansible
git clone https://github.com/dev-sec/ansible-os-hardening.git

cd ansible-os-hardening
tee playbook.yml <<<"- hosts: localhost
  connection: local
  become: yes
  roles:
    - roles/os_hardening" >/dev/null

sudo ansible-galaxy collection install ansible.posix
sudo ansible-playbook playbook.yml
