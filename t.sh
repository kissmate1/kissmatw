#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
echo -e "${GREEN}Csomaglista frissítése...${NC}"
if apt-get update -y; then
    echo -e "${GREEN}Csomaglista sikeresen frissítve.${NC}"
else
    echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"
    exit 1
fi

# Telepítsük a szükséges csomagokat
echo -e "${GREEN}Szükséges csomagok telepítése...${NC}"
if DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm nfs-kernel-server samba samba-common-bin; then
    echo -e "${GREEN}Csomagok sikeresen telepítve.${NC}"
else
    echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"
    exit 1
fi

# Node-RED telepítése (without --unsafe-perm flag)
echo -e "${GREEN}Node-RED telepítése...${NC}"
if npm install -g node-red@latest; then
    echo -e "${GREEN}Node-RED sikeresen telepítve.${NC}"
else
    echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"
    exit 1
fi

# Node-RED unit file létrehozása
echo -e "${GREEN}Node-RED rendszerindító fájl létrehozása...${NC}"
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
echo -e "${GREEN}Node-RED indítása...${NC}"
if systemctl daemon-reload && systemctl enable nodered.service && systemctl start nodered.service; then
    echo -e "${GREEN}Node-RED sikeresen elindítva.${NC}"
else
    echo -e "${RED}Hiba a Node-RED indításakor!${NC}"
    exit 1
fi

# Kérem, várjon néhány másodpercet, amíg minden szolgáltatás elindul...
echo -e "${GREEN}Kérem, várjon néhány másodpercet, amíg minden szolgáltatás elindul...${NC}"
sleep 5

# Ellenőrizzük a telepített szolgáltatások állapotát
echo -e "${GREEN}Telepített szolgáltatások állapota:${NC}"
all_services_ok=true
for service in ssh apache2 mariadb mosquitto nodered nfs-kernel-server samba; do
    echo -n "$service: "
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}fut${NC}"
    else
        echo -e "${RED}$service nem fut${NC}"
        all_services_ok=false
    fi
done

# NFS konfiguráció - megosztott könyvtár létrehozása
echo -e "${GREEN}NFS fájlmegosztás beállítása...${NC}"

# Készítsünk egy megosztott könyvtárat
mkdir -p /mnt/nfs_share

# A /etc/exports fájlban hozzáadjuk a megosztásokat, biztonságos IP-címekre korlátozva
echo "/mnt/nfs_share 192.168.1.0/24(rw,sync,no_subtree_check)" >> /etc/exports

# Az NFS szolgáltatás újraindítása, hogy a beállítások érvényesüljenek
if exportfs -a && systemctl restart nfs-kernel-server; then
    echo -e "${GREEN}NFS fájlmegosztás sikeresen beállítva.${NC}"
else
    echo -e "${RED}Hiba az NFS fájlmegosztás beállításakor!${NC}"
    exit 1
fi

# Samba megosztás konfigurálása
echo -e "${GREEN}Samba fájlmegosztás beállítása...${NC}"

# Samba konfigurálása
mkdir -p /srv/samba/share

# Samba konfiguráció hozzáadása
cat <<EOF >> /etc/samba/smb.conf

[share]
   path = /srv/samba/share
   browseable = yes
   read only = no
   guest ok = yes
   force user = nobody
   force group = nogroup
EOF

# A Samba szolgáltatás újraindítása
if systemctl restart smbd && systemctl enable smbd; then
    echo -e "${GREEN}Samba fájlmegosztás sikeresen beállítva.${NC}"
else
    echo -e "${RED}Hiba a Samba fájlmegosztás beállításakor!${NC}"
    exit 1
fi

# Ellenőrző üzenet a telepítés után
if $all_services_ok; then
    echo -e "${GREEN}Minden szolgáltatás sikeresen telepítve és fut.${NC}"
else
    echo -e "${RED}Néhány szolgáltatás nem fut. Kérjük, ellenőrizze a hibaüzeneteket és próbálja újra.${NC}"
    exit 1
fi

echo -e "${GREEN}A telepítés sikeresen befejeződött!${NC}"

# Indítsuk el az auto_backup.sh scriptet nohup segítségével, hogy a háttérben fusson
echo -e "${GREEN}Indítjuk az auto_backup.sh scriptet nohup használatával...${NC}"
nohup /path/to/auto_backup.sh &

echo -e "${GREEN}A rendszer állapotának automatikus mentése mostantól háttérben fut.${NC}"
