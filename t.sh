#!/bin/bash

# Indulás
clear
echo "Előkészületek..."
echo "Szükséges csomagok telepítése..."

# Frissítjük a csomaglistát
sudo apt update -y > /dev/null 2>&1

# curl telepítése (ha nincs telepítve)
echo "curl telepítése..."
sudo apt install -y curl > /dev/null 2>&1

# Node.js és npm telepítése (ha szükséges)
echo "Node.js és npm telepítése..."
curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash - > /dev/null 2>&1
sudo apt install -y nodejs > /dev/null 2>&1

# NPM frissítése
echo "NPM frissítése..."
sudo npm install -g npm@latest > /dev/null 2>&1

# Node-RED telepítése
echo "Node-RED telepítése..."
sudo npm install -g --unsafe-perm node-red > /dev/null 2>&1

# Tűzfal (UFW) konfigurálása
echo "Tűzfal beállítása..."
sudo ufw allow 1880/tcp > /dev/null 2>&1
sudo ufw enable > /dev/null 2>&1

# Node-RED indítása
echo "Node-RED indítása..."
nohup node-red & > /dev/null 2>&1

# Node-RED elindult?
if ps aux | grep '[n]ode-red' > /dev/null 2>&1
then
    echo "Node-RED sikeresen elindult!"
    echo "Node-RED elérhető a http://127.0.0.1:1880/ címen."
else
    echo "Hiba történt a Node-RED indítása során!"
    exit 1
fi

# Várakozás, hogy megbizonyosodjunk róla, hogy minden jól működik
sleep 5
