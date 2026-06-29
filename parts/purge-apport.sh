#!/bin/bash
sudo apt purge apport*
sudo apt autoremove -y
sudo rm -rf /var/crash/*
