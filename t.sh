#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Progreszszázalék változó
PROGRESS=0

# Progreszszázalék frissítése
update_progress() {
    local step=$1
    local total=$2
    PROGRESS=$(( (step * 100) / total ))
    echo -ne "Telepítés: $PROGRESS%   \r"
}

# A telepítési állapot folyamatos mutatása háttérben
show_progress() {
    while :; do
        echo -ne "Telepítés: $PROGRESS%   \r"
        sleep 1
    done
}

# A progressz megjelenítése háttérben
show_progress &

# Frissítsük a csomaglistát
echo -e "${GREEN}Csomaglista frissítése...${NC}"
update_progress 1 10
if apt-get update -y; then
    echo -e "${GREEN}Csomaglista sikeresen frissítve.${NC}"
else
    echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"
    exit 1
fi

# Telepítsük a szükséges csomagokat
echo -e "${GREEN}Szükséges csomagok telepítése...${NC}"
update_progress 2 10
if DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm nfs-common nfs-kernel-server samba samba-common-bin; then
    echo -e "${GREEN}Csomagok sikeresen telepítve.${NC}"
else
    echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"
    exit 1
fi

# Node-RED telepítése
echo -e "${GREEN}Node-RED telepítése...${NC}"
update_progress 3 10
if npm install -g node-red@latest; then
    echo -e "${GREEN}Node-RED sikeresen telepítve.${NC}"
else
    echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"
    exit 1
fi

# Node-RED rendszerindító fájl létrehozása
echo -e "${GREEN}Node-RED rendszerindító fájl létrehozása...${NC}"
update_progress 4 10
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
echo -e "${GREEN}Node-RED indítása...${NC}"
update_progress 5 10
if systemctl daemon-reload && systemctl enable nodered.service && systemctl start nodered.service; then
    echo -e "${GREEN}Node-RED sikeresen elindítva.${NC}"
else
    echo -e "${RED}Hiba a Node-RED indításakor!${NC}"
    exit 1
fi

# Kérjük be a felhasználótól az IP-címet az NFS és Samba megosztáshoz
echo -e "${GREEN}Adja meg az IP-címet (vagy IP-tartományt), amely hozzáférést kap a NFS és Samba megosztásokhoz:${NC}"
read -p "IP-cím (pl. 192.168.1.0/24): " SHARED_IP

# Ellenőrizzük, hogy érvényes IP-t adtak-e meg
if [[ ! "$SHARED_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(/[0-9]+)?$ ]]; then
    echo -e "${RED}Hibás IP-cím formátum! Kérem, próbálja újra.${NC}"
    exit 1
fi

# Ellenőrizzük a megadott IP-címet NFS és Samba konfigurációban
echo -e "${GREEN}Beállítjuk a NFS fájlmegosztást az IP-címhez: $SHARED_IP${NC}"
update_progress 6 10
mkdir -p /mnt/nfs_share
echo "/mnt/nfs_share $SHARED_IP(rw,sync,no_subtree_check)" >> /etc/exports

# Töröljük a régi cache-t és exportáljuk az új beállításokat
if exportfs -a && systemctl restart nfs-kernel-server; then
    echo -e "${GREEN}NFS fájlmegosztás sikeresen beállítva.${NC}"
else
    echo -e "${RED}Hiba az NFS fájlmegosztás beállításakor!${NC}"
    exit 1
fi

# Samba megosztás beállítása
echo -e "${GREEN}Beállítjuk a Samba fájlmegosztást az IP-címhez: $SHARED_IP${NC}"
update_progress 7 10
mkdir -p /srv/samba/share
cat <<EOF >> /etc/samba/smb.conf
[share]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   force group = nogroup
EOF

if systemctl restart smbd && systemctl enable smbd; then
    echo -e "${GREEN}Samba fájlmegosztás sikeresen beállítva.${NC}"
else
    echo -e "${RED}Hiba a Samba fájlmegosztás beállításakor!${NC}"
    exit 1
fi

# Összegzés
echo -e "${GREEN}A telepítés sikeresen befejeződött.${NC}"
update_progress 10 10

# Háttérben futtatjuk az auto_backup.sh scriptet
echo -e "${GREEN}Indítjuk az auto_backup.sh scriptet nohup használatával...${NC}"
nohup /path/to/auto_backup.sh &

echo -e "${GREEN}A rendszer állapotának automatikus mentése mostantól háttérben fut.${NC}"
