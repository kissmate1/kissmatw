#!/bin/bash

# ANSI színek definiálása
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # No Color

# Telepítési csík frissítése
update_progress_bar() {
    step=$1
    total_steps=8
    progress=$(( (step * 100) / total_steps ))
    bar_width=50
    filled=$(( (progress * bar_width) / 100 ))
    empty=$(( bar_width - filled ))
    echo -ne "${LIGHT_BLUE}["
    for ((i=0; i<filled; i++)); do echo -ne "#"; done
    for ((i=0; i<empty; i++)); do echo -ne " "; done
    echo -ne "] ${progress}%${NC}\r"
    [ "$step" -eq "$total_steps" ] && echo
}

# Ellenőrizze és telepítse a szükséges csomagokat
check_and_install_dependencies() {
    echo -e "${LIGHT_BLUE}Szükséges csomagok ellenőrzése...${NC}"

    # Ellenőrizzük a net-tools telepítését
    if ! command -v netstat > /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}net-tools telepítése (netstat szükséges)...${NC}"
        apt-get install -y net-tools > /dev/null 2>&1 || { echo -e "${RED}Hiba a net-tools telepítésekor!${NC}"; exit 1; }
    fi

    # Ellenőrizzük az ufw telepítését
    if ! command -v ufw > /dev/null 2>&1; then
        echo -e "${LIGHT_BLUE}ufw telepítése...${NC}"
        apt-get install -y ufw > /dev/null 2>&1 || { echo -e "${RED}Hiba az ufw telepítésekor!${NC}"; exit 1; }
    fi

    echo -e "${GREEN}Minden szükséges csomag telepítve van.${NC}"
}

# Szabad port keresése
find_free_port() {
    local port=1880
    while netstat -tuln | grep -q ":$port"; do
        ((port++))
    done
    echo $port
}

# Telepítési folyamat
install_process() {
    echo -e "${LIGHT_BLUE}Csomaglista frissítése...${NC}"
    apt-get update -y > /dev/null 2>&1 || { echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"; exit 1; }
    update_progress_bar 1

    echo -e "${LIGHT_BLUE}Szükséges csomagok telepítése...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl mosquitto mosquitto-clients nodejs npm mc mdadm > /dev/null 2>&1 || { echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"; exit 1; }
    update_progress_bar 2

    echo -e "${LIGHT_BLUE}Node-RED telepítése...${NC}"
    npm install -g node-red@latest > /dev/null 2>&1 || { echo -e "${RED}Hiba a Node-RED telepítésekor!${NC}"; exit 1; }
    update_progress_bar 3

    echo -e "${LIGHT_BLUE}Node-RED rendszerindító fájl létrehozása...${NC}"
    free_port=$(find_free_port)
    cat <<EOF > /etc/systemd/system/nodered.service
[Unit]
Description=Node-RED graphical event wiring tool
Wants=network.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=/home/$(whoami)/.node-red
ExecStart=/usr/bin/env node-red -p $free_port --max-old-space-size=512
Restart=always
Environment="NODE_OPTIONS=--max-old-space-size=512"
Nice=10
SyslogIdentifier=Node-RED
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
    update_progress_bar 4

    echo -e "${LIGHT_BLUE}Node-RED indítása a háttérben...${NC}"
    systemctl daemon-reload > /dev/null 2>&1
    systemctl enable nodered.service > /dev/null 2>&1
    systemctl start nodered.service > /dev/null 2>&1
    sleep 5
    if ! systemctl is-active --quiet nodered.service; then
        echo -e "${RED}Hiba a Node-RED indításakor!${NC}"
        exit 1
    fi
    update_progress_bar 5
}

# phpMyAdmin konfigurálása és Apache-beállítások
configure_phpmyadmin() {
    echo -e "${LIGHT_BLUE}phpMyAdmin konfigurálása...${NC}"
    
    # Apache konfigurálása phpMyAdmin számára
    if [ ! -f /etc/apache2/conf-enabled/phpmyadmin.conf ]; then
        ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-enabled/phpmyadmin.conf
    fi

    # Apache port módosítása (8080)
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf
    
    # Apache újraindítása
    systemctl restart apache2
    update_progress_bar 6
}

# UFW konfigurálása
configure_ufw() {
    echo -e "${LIGHT_BLUE}UFW tűzfal konfigurálása...${NC}"
    
    # Alapértelmezett szabályok beállítása
    ufw default deny incoming   # Alapértelmezett bejövő kapcsolatok blokkolása
    ufw default allow outgoing  # Kimenő kapcsolatok engedélyezése

    # Portok engedélyezése
    ufw allow ssh       # SSH (22)
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS
    ufw allow 1880/tcp  # Node-RED
    ufw allow 1883/tcp  # Mosquitto
    ufw allow 8080/tcp  # phpMyAdmin

    # Tűzfal engedélyezése
    ufw --force enable > /dev/null 2>&1 || { echo -e "${RED}Hiba az UFW konfigurálásakor!${NC}"; exit 1; }
    
    # Ellenőrizzük az UFW státuszát
    ufw status verbose
    update_progress_bar 7
}

# Ellenőrzés és telepítési folyamat indítása
check_and_install_dependencies
install_process

# phpMyAdmin és UFW konfigurálása
configure_phpmyadmin
configure_ufw

# Szolgáltatások ellenőrzése
echo -e "\n${LIGHT_BLUE}Szolgáltatások ellenőrzése...${NC}"
declare -a services=("ssh" "apache2" "mariadb" "mosquitto" "node-red")

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

# Összegzés
if $all_services_running; then
    echo -e "${GREEN}A telepítés sikeresen befejeződött. Minden szolgáltatás fut.${NC}"
    echo -e "${GREEN}Node-RED elérhető a $free_port porton.${NC}"
else
    echo -e "${RED}A telepítés befejeződött, de néhány szolgáltatás nem fut.${NC}"
fi
