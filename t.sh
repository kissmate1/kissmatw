#!/bin/bash

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color (alapértelmezett szín visszaállítása)

# Telepítési csík frissítése
update_progress_bar() {
    step=$1
    total_steps=6
    progress=$(( (step * 100) / total_steps )) # Százalékos arány kiszámítása
    bar_width=50                               # A csík szélessége

    filled=$(( (progress * bar_width) / 100 )) # Kitöltött rész kiszámítása
    empty=$(( bar_width - filled ))            # Üres rész kiszámítása

    echo -ne "${LIGHT_BLUE}[" 
    for ((i=0; i<filled; i++)); do echo -ne "#"; done
    for ((i=0; i<empty; i++)); do echo -ne " "; done
    echo -ne "] ${progress}%${NC}\r"

    # Csak az utolsó lépés után ugrik új sorra
    if [ "$step" -eq "$total_steps" ]; then
        echo -ne "\n"
    fi
}

# Csomagok telepítése és szükséges alkalmazások beállítása
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
ExecStart=/usr/bin/env node-red start --max-old-space-size=512
Restart=always
Environment="NODE_OPTIONS=--max-old-space-size=512"
Nice=10
EnvironmentFile=-/etc/nodered/.env
SyslogIdentifier=Node-RED
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    update_progress_bar 4

    echo -e "${LIGHT_BLUE}Node-RED indítása...${NC}"
    systemctl daemon-reload > /dev/null 2>&1 && systemctl enable nodered.service > /dev/null 2>&1
    nohup node-red start > /dev/null 2>&1 &
    sleep 5
    if ! pgrep -f node-red > /dev/null; then
        echo -e "${RED}Hiba a Node-RED indításakor!${NC}"
        exit 1
    fi
    update_progress_bar 5

    echo -e "${LIGHT_BLUE}Auto backup script indítása...${NC}"
    nohup /path/to/auto_backup.sh > /dev/null 2>&1 &
    update_progress_bar 6
}

# Telepítési folyamat elindítása
install_process &

# Telepítési lépések frissítése
steps=("Csomaglista frissítése" "Szükséges csomagok telepítése" "Node-RED telepítése" "Node-RED rendszerindító fájl létrehozása" "Node-RED indítása" "auto_backup.sh indítása")
for i in "${!steps[@]}"; do
    update_progress_bar $((i+1))
done

wait

# Telepített alkalmazások ellenőrzése
echo -e "\n${LIGHT_BLUE}Telepített alkalmazások ellenőrzése és indítása...${NC}"

declare -a services=("ufw" "ssh" "apache2" "mariadb" "mosquitto" "node-red")

# Ellenőrzési üzenetek
all_services_running=true
for service in "${services[@]}"
do
    echo -e "${LIGHT_BLUE}$service ellenőrzése...${NC}"
    if systemctl is-active --quiet $service; then
        echo -e "${GREEN}$service fut.${NC}"
    else
        echo -e "${RED}$service nem fut.${NC}"
        all_services_running=false
    fi
done

# Telepítés összegzése
if $all_services_running; then
    echo -e "${GREEN}A telepítés sikeresen befejeződött. Minden szolgáltatás fut.${NC}"
else
    echo -e "${RED}A telepítés befejeződött, de néhány szolgáltatás nem fut. Kérjük, ellenőrizze a naplókat.${NC}"
fi
