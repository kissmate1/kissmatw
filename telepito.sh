#!/bin/bash

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl

# Node-RED telepítése (hivatalos script alapján)
bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) -y

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

# Node-RED indítás
node-red-start &

# MariaDB felhasználó létrehozása
mysql -u root <<MYSQL_SCRIPT
CREATE USER 'admin'@'localhost' IDENTIFIED BY 'admin123';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Indítsa újra a MariaDB-t a változtatások érvényesítéséhez
systemctl restart mariadb

