#!/bin/bash

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl

# Node-RED telepítése (hivatalos script alapján)
curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered

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

# Node-red inditás
node-red start &

# Mariadb felhasználó
mariadb -u root -p
CREATE USER 'username'@'localhost' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
EXIT;
