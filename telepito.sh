#!/bin/bash

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin

# Node-RED telepítése (hivatalos script alapján)
curl -sL https://deb.nodesource.com/setup_14.x | bash -
apt-get install -y nodejs
npm install -g --unsafe-perm node-red

# SSH szolgáltatás elindítása
systemctl enable ssh
systemctl start ssh

# Apache szolgáltatás elindítása
systemctl enable apache2
systemctl start apache2

# MariaDB szolgáltatás elindítása
systemctl enable mariadb
systemctl start mariadb

# UFW konfiguráció
ufw allow 22
ufw allow 80
ufw allow 1880
ufw allow 1883
ufw enable
