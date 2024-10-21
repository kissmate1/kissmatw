#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients

# Node-RED telepítése
curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
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

# Node-RED indítása
systemctl enable nodered
systemctl start nodered

# Ellenőrizzük a telepített szolgáltatások állapotát
echo "Telepített szolgáltatások állapota:"
for service in ssh apache2 mariadb mosquitto nodered; do
    echo -n "$service: "
    systemctl is-active --quiet $service && echo "fut" || echo "nem fut"
done

echo "A telepítés sikeresen befejeződött!"
