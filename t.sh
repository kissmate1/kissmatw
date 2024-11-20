#!/bin/bash

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Telepítési folyamat definíciója
install_process() {
    echo -e "${LIGHT_BLUE}Csomaglista frissítése...${NC}"
    apt-get update -y > /dev/null 2>&1 || { echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"; exit 1; }
    update_progress_bar 1

    echo -e "${LIGHT_BLUE}Szükséges csomagok telepítése...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm > /dev/null 2>&1 || { echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"; exit 1; }
    update_progress_bar 2

    echo -e "${LIGHT_BLUE}Node-RED telepítése...${NC}"
    npm install -g node-red@latest > /dev/null 2>&1 || { echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"; exit 1; }
    update_progress_bar 3

    echo -e "${LIGHT_BLUE}Node-RED rendszerindító fájl létrehozása...${NC}"
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
    update_progress_bar 4

    echo -e "${LIGHT_BLUE}Node-RED indítása...${NC}"
    systemctl daemon-reload > /dev/null 2>&1 && systemctl enable nodered.service > /dev/null 2>&1 && nohup node-red start > /dev/null 2>&1 & || { echo -e "${RED}Hiba a Node-RED indításakor!${NC}"; exit 1; }
    update_progress_bar 5

    nohup /path/to/auto_backup.sh > /dev/null 2>&1 &
    update_progress_bar 6
}

# Telepítési folyamat háttérbe küldése
install_process &

# Telepítési csík frissítése
update_progress_bar() {
    step=$1
    total_steps=6
    progress=$(( (step) * 100 / total_steps ))
    echo -ne "${LIGHT_BLUE}["
    for ((j=0; j<=progress/2; j++)); do echo -ne "#"; done
    for ((j=progress/2+1; j<=50; j++)); do echo -ne " "; done
    echo -ne "] ${progress}%${NC}\r"
    echo -ne "\n"
}

# Minden lépéshez frissítse a telepítési csíkot és százalékos kijelzőt
steps=("Csomaglista frissítése" "Szükséges csomagok telepítése" "Node-RED telepítése" "Node-RED rendszerindító fájl létrehozása" "Node-RED indítása" "auto_backup.sh indítása")
for i in "${!steps[@]}"; do
    update_progress_bar $((i+1))
done

wait

# Telepített alkalmazások ellenőrzése és indítása
echo -e "\n${LIGHT_BLUE}Telepített alkalmazások ellenőrzése és indítása...${NC}"

declare -a services=("ufw" "ssh" "nmap" "apache2" "mariadb" "mosquitto" "node-red")

for service in "${services[@]}"
do
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}$service fut.${NC}"
    else
        echo -e "${RED}$service nem fut.${NC}"
        if [ $service == "node-red" ]; then
            nohup node-red start > /dev/null 2>&1 && echo -e "${GREEN}$service sikeresen elindítva.${NC}" || echo -e "${RED}Hiba a $service indításakor!${NC}"
        else
            systemctl start $service > /dev/null 2>&1 && echo -e "${GREEN}$service sikeresen elindítva.${NC}" || echo -e "${RED}Hiba a $service indításakor!${NC}"
        fi
    fi
done
