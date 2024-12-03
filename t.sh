#!/bin/bash

# Színek a kimenethez
RED='\033[0;31m'
GREEN='\033[0;32m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m' # Alapértelmezett szín visszaállítása

# UFW konfigurálása
configure_ufw() {
    echo -e "${LIGHT_BLUE}UFW tűzfal konfigurálása...${NC}"

    # Ellenőrizzük, hogy létezik-e a /sbin/ufw
    if [ ! -x /sbin/ufw ]; then
        echo -e "${RED}Nem található a /sbin/ufw.${NC}"
        exit 1
    fi

    # UFW alaphelyzetbe állítása
    if ! /sbin/ufw reset > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az UFW alaphelyzetbe állítása.${NC}"
        exit 1
    fi

    # Alapértelmezett szabályok beállítása
    if ! /sbin/ufw default deny incoming > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az alapértelmezett bejövő szabályok beállítása.${NC}"
        exit 1
    fi

    if ! /sbin/ufw default allow outgoing > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az alapértelmezett kimenő szabályok beállítása.${NC}"
        exit 1
    fi

    # Engedélyezett portok beállítása
    for port in ssh 80 443 1880; do
        if ! /sbin/ufw allow $port/tcp > /dev/null 2>&1; then
            echo -e "${RED}Nem sikerült a(z) $port/tcp port engedélyezése.${NC}"
            exit 1
        fi
    done

    # UFW engedélyezése
    if ! /sbin/ufw --force enable > /dev/null 2>&1; then
        echo -e "${RED}Nem sikerült az UFW engedélyezése.${NC}"
        exit 1
    fi

    echo -e "${GREEN}UFW tűzfal sikeresen konfigurálva.${NC}"
}

# Fő script logika
echo -e "${LIGHT_BLUE}Előkészületek...${NC}"

# Node-RED telepítése
echo -e "${LIGHT_BLUE}Node-RED telepítése...${NC}"
npm install -g --unsafe-perm node-red > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}Nem sikerült a Node-RED telepítése.${NC}"
    exit 1
fi
echo -e "${GREEN}Node-RED sikeresen telepítve.${NC}"

# UFW konfiguráció meghívása
configure_ufw

# Node-RED indítása
echo -e "${LIGHT_BLUE}Node-RED indítása...${NC}"
node-red-start > /dev/null 2>&1 &

# Kész
echo -e "${GREEN}Minden kész! A Node-RED fut az 1880-as porton.${NC}"
