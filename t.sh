#!/bin/bash

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients

# Node.js telepítése (hivatalos NodeSource tárolóból - legújabb LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -  # Vagy cseréld 20.x-re a legújabb verzióhoz
apt-get install -y nodejs

# Node-RED telepítése a legújabb verzióval
npm install -g --unsafe-perm node-red@latest

# Szolgáltatások engedélyezése és indítása
systemctl enable ssh
systemctl start ssh

systemctl enable apache2
systemctl start apache2

systemctl enable mariadb
systemctl start mariadb

systemctl enable mosquitto
systemctl start mosquitto

# UFW tűzfal konfiguráció
ufw allow 22    # SSH engedélyezése
ufw allow 80    # HTTP engedélyezése
ufw allow 1880  # Node-RED engedélyezése
ufw allow 1883  # MQTT engedélyezése
ufw enable

# Node-RED rendszerindító szolgáltatás létrehozása
cat <<EOF > /etc/systemd/system/node-red.service
[Unit]
Description=Node-RED
After=network.target

[Service]
ExecStart=/usr/bin/env node-red
Restart=on-failure
User=$(whoami)
Group=$(id -gn)
Environment=NODE_OPTIONS=--max-old-space-size=256

[Install]
WantedBy=multi-user.target
EOF

# Szolgáltatás engedélyezése és indítása
systemctl enable node-red
systemctl start node-red

# MariaDB admin felhasználó létrehozása, alapértelmezett jelszó
db_password="admin123"
mysql -u root <<MYSQL_SCRIPT
CREATE USER 'admin'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# Indítsa újra a MariaDB-t a változtatások érvényesítéséhez
systemctl restart mariadb

# Ellenőrizzük a telepített szolgáltatások állapotát
echo "Telepített szolgáltatások állapota:"
for service in ssh apache2 mariadb mosquitto node-red; do
    echo -n "$service: "
    systemctl is-active --quiet $service && echo "fut" || echo "nem fut"
done

echo "A telepítés sikeresen befejeződött!"
