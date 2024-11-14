#!/bin/bash

# Készítsünk egy könyvtárat a mentésekhez
BACKUP_DIR="/var/backups/system_state"
mkdir -p $BACKUP_DIR

# A rendszer állapotát mentő függvény
save_system_state() {
    # Az aktuális idő és dátum
    timestamp=$(date +"%Y%m%d_%H%M%S")
    
    # Mentési fájlok elnevezése
    system_info_file="$BACKUP_DIR/system_info_$timestamp.txt"
    processes_file="$BACKUP_DIR/processes_$timestamp.txt"
    disk_usage_file="$BACKUP_DIR/disk_usage_$timestamp.txt"
    memory_usage_file="$BACKUP_DIR/memory_usage_$timestamp.txt"
    uptime_file="$BACKUP_DIR/uptime_$timestamp.txt"

    # A rendszer információinak mentése
    echo "Mentés dátuma: $timestamp" > $system_info_file
    echo -e "\n### Rendszer információ ###" >> $system_info_file
    uname -a >> $system_info_file

    # Folyamatok listájának mentése
    echo -e "\n### Folyamatok (ps aux) ###" > $processes_file
    ps aux >> $processes_file

    # Lemezhasználat mentése
    echo -e "\n### Lemezhasználat (df -h) ###" > $disk_usage_file
    df -h >> $disk_usage_file

    # Memóriahasználat mentése
    echo -e "\n### Memóriahasználat (free -h) ###" > $memory_usage_file
    free -h >> $memory_usage_file

    # Uptime mentése
    echo -e "\n### Rendszer uptime ###" > $uptime_file
    uptime >> $uptime_file

    echo "Rendszer állapot mentve: $timestamp"
}

# Végtelen ciklus, amely félóránként menti az állapotot
while true; do
    save_system_state
    # 30 perc várakozás (1800 másodperc)
    sleep 1800
done
