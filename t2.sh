#!/bin/bash

##############################################
# 🔧 SZÍNEK ÉS PROGRESS BAR DEFINÍCIÓ
##############################################
GREEN='\033[0;32m'
RED='\033[0;31m'
LIGHT_BLUE='\033[1;34m'
NC='\033[0m'

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

##############################################
# ⚙️  RENDSZER ELŐKÉSZÍTÉSE
##############################################
prepare_system() {
    echo -e "${LIGHT_BLUE}Előkészületek...${NC}"
    apt-get update -y > /dev/null 2>&1 || { echo -e "${RED}Hiba a csomaglista frissítésekor!${NC}"; exit 1; }
    apt-get install -y sudo net-tools curl coreutils > /dev/null 2>&1 || { echo -e "${RED}Hiba a szükséges csomagok telepítésekor!${NC}"; exit 1; }
    update_progress_bar 1
}

##############################################
# 📦 CSOMAGOK TELEPÍTÉSE
##############################################
install_packages() {
    echo -e "${LIGHT_BLUE}Szükséges csomagok telepítése...${NC}"
    DEBIAN_FRONTEND=noninteractive apt-get install -y ufw ssh nmap apache2 libapache2-mod-php mariadb-server phpmyadmin curl nodejs npm mc mdadm > /dev/null 2>&1 || {
        echo -e "${RED}Hiba a csomagok telepítésekor!${NC}"; exit 1;
    }
    update_progress_bar 2
}

##############################################
# 🛠️ PHPMYADMIN FELHASZNÁLÓ LÉTREHOZÁSA
##############################################
setup_phpmyadmin_user() {
    echo -e "${LIGHT_BLUE}phpMyAdmin felhasználó létrehozása és konfigurálása...${NC}"
    mysql -u root -p <<EOF
CREATE USER IF NOT EXISTS 'admin'@'localhost' IDENTIFIED BY 'admin';
GRANT ALL PRIVILEGES ON *.* TO 'admin'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF
    if [ $? -ne 0 ]; then
        echo -e "${RED}Hiba a phpMyAdmin felhasználó létrehozásakor!${NC}"
        exit 1
    fi
    update_progress_bar 3
}

##############################################
# 🔥 UFW TŰZFAL KONFIGURÁLÁSA
##############################################
configure_ufw() {
    echo -e "${LIGHT_BLUE}UFW tűzfal konfigurálása...${NC}"
    /sbin/ufw default deny incoming > /dev/null 2>&1
    /sbin/ufw default allow outgoing > /dev/null 2>&1
    /sbin/ufw allow ssh > /dev/null 2>&1
    /sbin/ufw allow 80/tcp > /dev/null 2>&1
    /sbin/ufw allow 443/tcp > /dev/null 2>&1
    /sbin/ufw allow 8080/tcp > /dev/null 2>&1
    /sbin/ufw --force enable > /dev/null 2>&1 || { echo -e "${RED}Hiba az UFW konfigurálásakor!${NC}"; exit 1; }
    echo -e "${GREEN}UFW tűzfal sikeresen konfigurálva.${NC}"
    update_progress_bar 4
}

##############################################
# 🌐 PHPMYADMIN KONFIGURÁCIÓ
##############################################
configure_phpmyadmin() {
    echo -e "${LIGHT_BLUE}phpMyAdmin konfigurálása...${NC}"
    if [ ! -f /etc/apache2/conf-enabled/phpmyadmin.conf ]; then
        ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-enabled/phpmyadmin.conf
    fi
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf
    systemctl restart apache2 > /dev/null 2>&1 || { echo -e "${RED}Hiba az Apache újraindításakor!${NC}"; exit 1; }
    echo -e "${GREEN}phpMyAdmin elérhető a 8080-as porton.${NC}"
    update_progress_bar 5
}

##############################################
# ✅ SZOLGÁLTATÁSOK ELLENŐRZÉSE
##############################################
check_services() {
    echo -e "\n${LIGHT_BLUE}Szolgáltatások ellenőrzése...${NC}"
    declare -a services=("ssh" "apache2" "mariadb")

    all_services_running=true
    for service in "${services[@]}"; do
        if ! systemctl is-active --quiet $service; then
            echo -e "${RED}$service nem fut!${NC}"
            all_services_running=false
        fi
    done

    if [ "$all_services_running" = true ]; then
        echo -e "${GREEN}Minden szolgáltatás sikeresen fut.${NC}"
    else
        echo -e "${RED}Egy vagy több szolgáltatás nem fut.${NC}"
        exit 1
    fi
    update_progress_bar 6
}

##############################################
# ▶️ FŐ FOLYAMAT
##############################################
main() {
    echo -e "${LIGHT_BLUE}Telepítési folyamat megkezdése...${NC}"
    update_progress_bar 0
    prepare_system
    install_packages
    setup_phpmyadmin_user
    configure_ufw
    configure_phpmyadmin
    check_services
    update_progress_bar 7
    echo -e "${GREEN}Telepítési folyamat befejezve!${NC}"
    update_progress_bar 8
}

main
