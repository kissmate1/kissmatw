#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Frissítsük a csomaglistát
echo -e "${BLUE}Csomaglista frissítése...${NC}"
apt-get update -y > /dev/null 2>&1 && echo -e "${BLUE}Csomaglista sikeresen frissítve.${NC}" || { echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"; exit 1; }

# Telepítsük a szükséges csomagokat
echo -e "${BLUE}Szükséges csomagok telepítése...${NC}"
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm > /dev/null 2>&1 && echo -e "${BLUE}Csomagok sikeresen telepítve.${NC}" || { echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"; exit 1; }

# Node-RED telepítése
echo -e "${BLUE}Node-RED telepítése...${NC}"
npm install -g node-red@latest > /dev/null 2>&1 && echo -e "${BLUE}Node-RED sikeresen telepítve.${NC}" || { echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"; exit 1; }

# Node-RED rendszerindító fájl létrehozása
echo -e "${BLUE}Node-RED rendszerindító fájl létrehozása...${NC}"
cat <<EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/.node-red
ExecStart=/usr/bin/env node-red start --max-old-space-size=256
Restart=always
Environment="NODE_OPTIONS=--max-old-space-size=256"
Nice=10
EnvironmentFile=-/etc/nodered/.env
SyslogIdentifier=Node-RED
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

# Node-RED indítása
echo -e "${BLUE}Node-RED indítása...${NC}"
systemctl daemon-reload > /dev/null 2>&1 && systemctl enable nodered.service > /dev/null 2>&1 && systemctl start nodered.service > /dev/null 2>&1 && echo -e "${BLUE}Node-RED sikeresen elindítva.${NC}" || { echo -e "${RED}Hiba a Node-RED indításakor!${NC}"; exit 1; }

# Összegzés
echo -e "${BLUE}A telepítés sikeresen befejeződött.${NC}"

# Háttérben futtatjuk az auto_backup.sh scriptet
echo -e "${BLUE}Indítjuk az auto_backup.sh scriptet nohup használatával...${NC}"
nohup /path/to/auto_backup.sh > /dev/null 2>&1 &

echo -e "${BLUE}A rendszer állapotának automatikus mentése mostantól háttérben fut.${NC}"

# Telepített alkalmazások ellenőrzése és indítása
echo -e "${BLUE}Telepített alkalmazások ellenőrzése és indítása...${NC}"

declare -a services=("ufw" "ssh" "nmap" "apache2" "mariadb" "mosquitto" "node-red")

for service in "${services[@]}"
do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}$service fut.${NC}"
    else
        echo -e "${RED}$service nem fut.${NC}"
        systemctl start $service > /dev/null 2>&1 && echo -e "${GREEN}$service sikeresen elindítva.${NC}" || echo -e "${RED}Hiba a $service indításakor!${NC}"
    fi
done
