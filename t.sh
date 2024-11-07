#!/bin/bash
set -e  # Azonnali kilépés, ha egy parancs nem nullával tér vissza
set -x  # Hibakeresés engedélyezése, a végrehajtott parancsok megjelenítéséhez

# A script saját magát futtathatóvá teszi
chmod +x "$0"

# Frissítsük a csomaglistát
PATH=$PATH:"/sbin"
apt-get update -y

# Telepítsük a szükséges csomagokat
DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm nfs-kernel-server

# Node-RED telepítése
npm install -g --unsafe-perm node-red@latest

# VirtualBox telepítése Oracle Repositoryből
# echo "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -cs) contrib" | tee /etc/apt/sources.list.d/virtualbox.list
# wget -q https://www.virtualbox.org/download/oracle_vbox_2016.asc -O- | apt-key add -
# apt-get update -y
# apt-get install -y virtualbox-6.1

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
for service in ssh apache2 mariadb mosquitto nodered nfs-kernel-server; do
    echo -n "$service: "
    if systemctl is-active --quiet $service; then
        echo "fut"
    else
        echo "nem fut"
    fi
done

# RAID tömb létrehozása az mdadm használatával
# Ez csak egy példa, és csak akkor érdemes futtatni, ha tényleg két eszköz áll rendelkezésre!

# Ellenőrizzük, hogy van-e két szabad lemez (pl. /dev/sdb és /dev/sdc)
echo "Ellenőrizd, hogy két szabad lemez van: /dev/sdb és /dev/sdc"
lsblk

# Ha a lemezek jelen vannak, RAID1 létrehozása
if [ -b /dev/sdb ] && [ -b /dev/sdc ]; then
    echo "RAID1 tömb létrehozása /dev/sdb és /dev/sdc lemezekkel"

    # A lemezek előkészítése
    wipefs --all /dev/sdb /dev/sdc  # Az esetleges régi fájlrendszer törlése
    mdadm --create /dev/md0 --level=1 --raid-devices=2 /dev/sdb /dev/sdc

    # RAID tömb állapotának ellenőrzése
    cat /proc/mdstat

    # A RAID tömb fájlrendszerének létrehozása (pl. ext4)
    mkfs.ext4 /dev/md0

    # Mountolás
    mkdir -p /mnt/raid
    mount /dev/md0 /mnt/raid

    # Az automatikus csatlakoztatás konfigurálása (fstab módosítása)
    echo '/dev/md0 /mnt/raid ext4 defaults 0 0' >> /etc/fstab
else
    echo "Nincsenek megfelelő lemezek (/dev/sdb, /dev/sdc) a RAID létrehozásához"
fi

# NFS konfiguráció - megosztott könyvtár létrehozása
echo "NFS fájlmegosztás beállítása..."

# Készítsünk egy megosztott könyvtárat
mkdir -p /mnt/nfs_share

# A /etc/exports fájlban hozzáadjuk a megosztásokat
echo "/mnt/nfs_share *(rw,sync,no_subtree_check)" >> /etc/exports

# Az NFS szolgáltatás újraindítása, hogy a beállítások érvényesüljenek
exportfs -a
systemctl restart nfs-kernel-server

# Tűzfal beállítások frissítése
ufw allow from any to any port 2049 proto tcp
ufw reload

echo "A telepítés sikeresen befejeződött!"
