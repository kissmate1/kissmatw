#!/bin/bash

# Színek a kijelzőhöz
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # Alapértelmezett szín

# Haladás kijelző funkció
update_progress_bar() {
    progress=$1
    echo -ne "${LIGHT_BLUE}Haladás: ["
    for ((i=0; i<100; i+=10)); do
        if [ $i -lt $progress ]; then
            echo -ne "#"
        else
            echo -ne "."
        fi
    done
    echo -e "] $progress%${NC}"
}

# UFW konfigurálása
configure_ufw() {
    echo -e "${LIGHT_BLUE}UFW tűzfal konfigurálása...${NC}"

    # Próbáljuk meg engedélyezni az alapértelmezett szabályokat
    if ! ufw default deny incoming > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az alapértelmezett bejövő szabályok beállítása.${NC}"
        exit 1
    fi

    if ! ufw default allow outgoing > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az alapértelmezett kimenő szabályok beállítása.${NC}"
        exit 1
    fi

    # Engedélyezzük az alapértelmezett portokat
    for port in ssh 80 443 1880; do
        if ! ufw allow $port/tcp > /dev/null 2>&1; then
            echo -e "${RED}Nem sikerült a(z) $port/tcp port engedélyezése.${NC}"
            exit 1
        fi
    done

    # Végül engedélyezzük a tűzfalat
    if ! ufw --force enable > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az UFW engedélyezése.${NC}"
        exit 1
    fi

    echo -e "${GREEN}UFW tűzfal sikeresen konfigurálva.${NC}"
    update_progress_bar 50
}

# Node-RED indítása
start_node_red() {
    echo -e "${LIGHT_BLUE}Node-RED indítása...${NC}"

    # Ellenőrizzük, hogy fut-e már a Node-RED
    if lsof -Pi :1880 -sTCP:LISTEN -t > /dev/null 2>&1; then
        echo -e "${RED}A Node-RED már fut a 1880-as porton.${NC}"
        return 1
    fi

    # Node-RED indítása
    node-red start &
    sleep 5

    # Ellenőrzés
    if ! lsof -Pi :1880 -sTCP:LISTEN -t > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült a Node-RED indítása.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Node-RED sikeresen elindult a 1880-as porton.${NC}"
    update_progress_bar 100
}

# Script kezdete
echo -e "${LIGHT_BLUE}Előkészületek...${NC}"
update_progress_bar 0

# Szükséges csomagok telepítése
echo -e "${LIGHT_BLUE}Szükséges csomagok telepítése...${NC}"
apt-get update -y && apt-get install -y ufw nodejs npm
update_progress_bar 20

# Node-RED telepítése
echo -e "${LIGHT_BLUE}Node-RED telepítése...${NC}"
npm install -g --unsafe-perm node-red
update_progress_bar 40

# UFW konfigurálása
configure_ufw

# Node-RED indítása
start_node_red
