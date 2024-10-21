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

# Szolgáltatások engedélyezése és indítása
for service in ssh apache2 mariadb mosquitto; do
    systemctl enable $service
    systemctl start $service
done

# UFW tűzfal konfiguráció
ufw allow 22    # SSH engedélyezése
ufw allow 80    # HTTP engedélyezése
ufw allow 1880  # Node-RED engedélyezése
ufw allow 1883  # MQTT engedélyezése
ufw enable

# VirtualBox port beállítások
VBoxManage modifyvm "VM_NAME" --natpf1 "ssh,tcp,,2222,,22"
VBoxManage modifyvm "VM_NAME" --natpf1 "http,tcp,,8080,,80"
VBoxManage modifyvm "VM_NAME" --natpf1 "nodered,tcp,,1880,,1880"
VBoxManage modifyvm "VM_NAME" --natpf1 "mqtt,tcp,,1883,,1883"

# MariaDB admin felhasználó létrehozása, alapértelmezett jelszó
read -sp "Kérem, adja meg az admin jelszót: " db_password
echo
mysql -u root <<MYSQL_SCRIPT
CREATE USER 'admin'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Indítsa újra a MariaDB-t a változtatások érvényesítéséhez
systemctl restart mariadb

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
