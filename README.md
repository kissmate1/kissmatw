
# Záróvizsga Gyakorlófeladat – Részletes Megoldás

## 1. Hálózati eszközök telepítése és konfigurálása (Cisco)

### 1.1. Alap-topológia felépítése

Kapcsolja össze a kapcsolókat, routereket és klienseket a kapott topológiaábra szerint. A két teszt PC bárhova csatlakoztatható.

### 1.2. VLAN-ok létrehozása kapcsolókon

```bash
enable
configure terminal
vlan 10
name BOSS
exit
vlan 20
name HR
exit
vlan 30
name ADMIN
exit
vlan 40
name OFFICE
exit

interface range fa0/1 - 2
switchport mode access
switchport access vlan 10
exit

interface range fa0/3 - 4
switchport mode access
switchport access vlan 20
exit

interface range fa0/5 - 6
switchport mode access
switchport access vlan 30
exit

interface range fa0/7 - 8
switchport mode access
switchport access vlan 40
exit

interface fa0/24
switchport trunk encapsulation dot1q
switchport mode trunk
exit
```

### 1.3. Inter-VLAN routing ROUTER_A-n

```bash
interface g0/0.10
encapsulation dot1Q 10
ip address 192.168.10.1 255.255.255.0
exit

interface g0/0.20
encapsulation dot1Q 20
ip address 192.168.20.1 255.255.255.0
exit

interface g0/0.30
encapsulation dot1Q 30
ip address 192.168.30.1 255.255.255.0
exit

interface g0/0.40
encapsulation dot1Q 40
ip address 192.168.40.1 255.255.255.0
exit
```

### 1.4. DHCP konfiguráció ROUTER_A-n

```bash
ip dhcp excluded-address 192.168.40.1 192.168.40.10
ip dhcp pool OFFICE
network 192.168.40.0 255.255.255.0
default-router 192.168.40.1
dns-server 8.8.8.8
```

### 1.5. ROUTER_B és SOHO router közötti kapcsolat

**ROUTER_B:**

```bash
interface g0/1
ip address 10.0.0.1 255.255.255.252
no shutdown
```

**SOHO router:**

```bash
interface g0/0
ip address 10.0.0.2 255.255.255.252
no shutdown
```

### 1.6. SOHO LAN DHCP és routing

```bash
interface g0/1
ip address 192.168.50.1 255.255.255.0
no shutdown

ip dhcp excluded-address 192.168.50.1 192.168.50.79
ip dhcp excluded-address 192.168.50.101 192.168.50.254
ip dhcp pool SOHO_LAN
network 192.168.50.0 255.255.255.0
default-router 192.168.50.1
dns-server 8.8.8.8

router rip
version 2
network 192.168.50.0
network 10.0.0.0
```

### 1.7. Útvonalak

**ROUTER_B:**

```bash
router rip
version 2
network 10.0.0.0
network 192.168.10.0
network 192.168.20.0
network 192.168.30.0
network 192.168.40.0
```

**ROUTER_A:**

```bash
ip route 192.168.50.0 255.255.255.0 10.0.0.1
```

### 1.8. Telnet korlátozása ACL-lel

```bash
access-list 10 permit 192.168.30.0 0.0.0.255

line vty 0 4
access-class 10 in
login local
transport input telnet
```

### 1.9. `admin01` felhasználó létrehozása

```bash
username admin01 privilege 15 secret vizsga

line con 0
login local

line vty 0 4
login local
transport input telnet
```

---

## 2. Windows Server konfiguráció

- Bejelentkezés
- AD DS és DNS szerepkör telepítése
- Tartományvezérlő létrehozása
- OU-k és felhasználók kezelése
- DHCP és fájlszerver konfigurálása
- GPO létrehozása

---

## 3. Felhőszolgáltatások (SaaS)

- Gmail regisztráció
- Dropbox fiók létrehozása
- `Bolyai` mappa és `vizsga.txt` feltöltése
- Fiókok törlése

---

## 4. Azure virtuális gép

- Virtuális gép létrehozása (Windows Server 2019)
- Webszolgáltatás telepítése
- Saját név megjelenítése weboldalon
- Gép leállítása és törlése
