#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm

# Node-RED telepítése
npm install -g --unsafe-perm node-red@latest

# VirtualBox telepítése Oracle Repositoryből
#echo "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/virtualbox.list
#wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
#apt-get update -y
#apt-get install -y virtualbox-6.1

# Node-RED unit file létrehozása
cat <<EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/.node-red
ExecStart=/usr/bin/env node-red-pi --max-old-space-size=256
Restart=always
Environment="NODE_OPTIONS=--max-old-space-size=256"
# Nice options
Nice=10
EnvironmentFile=-/etc/nodered/.env
# Make available to all devices
SyslogIdentifier=Node-RED
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Node-RED indítása
systemctl daemon-reload
systemctl enable nodered.service
systemctl start nodered.service

# Ellenőrizzük a telepített szolgáltatások állapotát
echo "Telepített szolgáltatások állapota:"
for service in ssh apache2 mariadb mosquitto nodered; do
    echo -n "$service: "
    systemctl is-active --quiet $service && echo "fut" || echo "nem fut"
done

echo "A telepítés sikeresen befejeződött!"
