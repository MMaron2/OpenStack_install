## 0. Minimalne wymagania sprzętowe oraz konfiguracja maszyn wirtualnych
### **Controller Node**

| Parametr | Wartość |
|----------|----------|
| **CPU** | min. 4 vCPU |
| **RAM** | min. 8 GB |
| **Dysk** | min. 40 GB |
| **Sieć** | 2 interfejsy (internal + external) |
| **Rola** | Keystone, Glance, Neutron, Nova API, Heat, Horizon, RabbitMQ, MariaDB |

---

### **Compute Node**

| Parametr | Wartość |
|----------|----------|
| **CPU** | min. 2 vCPU |
| **RAM** | min. 4 GB |
| **Dysk** | 20–40 GB |
| **Sieć** | 1–2 interfejsy |
| **Rola** | Nova compute + Neutron agent |

---

### 3. Opcjonalny Storage Node (dla Cinder/Swift)

| Parametr | Wartość |
|----------|----------|
| **CPU** | min. 2 vCPU |
| **RAM** | min. 4 GB |
| **Dysk systemowy** | 20 GB |
| **Dyski dla storage** | +20–100 GB (LVM / Ceph / Swift) |
| **Rola** | Cinder-volume lub Swift |

## 1. Przygotowanie środowiska
Wszystkie poniższe kroki wykonaj na **każdym węźle w zależności jakiej konfiguracji używamy**: controller, compute, storage.

---

### 1.1. Aktualizacja systemu

```bash
sudo apt update && sudo apt upgrade -y
#Instalacja niezbędnych pakietów (SSH, narzędzia systemowe)
sudo apt install -y ssh openssh-server curl vim git net-tools
#Sprawdzenie statusu SSH:
sudo systemctl status ssh
#Jeżeli SSH nie działa:
sudo systemctl enable --now ssh
```
### 1.2. Konfiguracja /etc/hosts zgodnie z konfiguracją kart sieciowych podczas instalacji systemu
```bash
sudo nano /etc/hosts
#Dodaj wpisy (dopasuj IP do swojej sieci):
192.168.56.10   controller
192.168.56.11   compute
192.168.56.12   storage
#Test połączeń:
ping -c 3 controller
ping -c 3 compute
ping -c 3 storage
```

## 2. Przygotowanie dostępu SSH i sudo (WYMAGANE przed uruchomieniem Ansible)

Przed rozpoczęciem pracy z Ansible konieczne jest skonfigurowanie bezhasłowego dostępu SSH oraz umożliwienie użytkownikowi wykonywania poleceń `sudo` bez podawania hasła.

### 2.1. Konfiguracja sudo bez hasła

Na **każdym węźle w zależności jakiej konfiguracji używamy** (controller, compute, storage) uruchom:

```bash
sudo visudo
# Na końcu pliku dodaj wpis (zamień ubuntu na nazwę używanego użytkownika, jeśli jest inna):
ubuntu ALL=(ALL) NOPASSWD: ALL
```

