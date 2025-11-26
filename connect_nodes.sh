#!/bin/bash
set -e

# --- Kolory ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# --- Flagi dla node'ów ---
USE_CONTROLLER=false
USE_COMPUTE=false
USE_STORAGE=false

# --- Obsługa argumentów ---
if [ $# -lt 1 ]; then
    log_error "Nie podano żadnych node! Użycie:"
    echo "  ./install_openstack.sh controller compute storage"
    echo "Np:"
    echo "  ./install_openstack.sh controller compute"
    exit 1
fi

for ARG in "$@"; do
    case "$ARG" in
        controller)
            USE_CONTROLLER=true
            ;;
        compute)
            USE_COMPUTE=true
            ;;
        storage)
            USE_STORAGE=true
            ;;
        *)
            log_warn "Nieznany argument: $ARG (dozwolone: controller, compute, storage)"
            ;;
    esac
done

log_info "Wybrane nody:"
[ "$USE_CONTROLLER" = true ] && echo "  - controller"
[ "$USE_COMPUTE"   = true ] && echo "  - compute"
[ "$USE_STORAGE"   = true ] && echo "  - storage"

echo ""
log_info "=== Konfiguracja węzłów OpenStack (IP + /etc/hosts + SSH) ==="
echo ""

echo ""
log_info "Usuwam stare wpisy controller/compute/storage z /etc/hosts..."

sudo sed -i '/controller/d' /etc/hosts
sudo sed -i '/compute/d' /etc/hosts
sudo sed -i '/storage/d' /etc/hosts

log_info "Usunięto stare wpisy z /etc/hosts."
echo ""

# --- Pobranie adresów IP tylko dla wybranych node'ów ---
HOSTS_UPDATE=""

if [ "$USE_CONTROLLER" = true ]; then
    read -p "Podaj adres IP do zarządzania dla CONTROLLER: " IP_CONTROLLER
    HOSTS_UPDATE+="${IP_CONTROLLER}   controller\n"
fi

if [ "$USE_COMPUTE" = true ]; then
    read -p "Podaj adres IP do zarządzania dla COMPUTE: " IP_COMPUTE
    HOSTS_UPDATE+="${IP_COMPUTE}      compute\n"
fi

if [ "$USE_STORAGE" = true ]; then
    read -p "Podaj adres IP do zarządzania dla STORAGE: " IP_STORAGE
    HOSTS_UPDATE+="${IP_STORAGE}      storage\n"
fi

echo ""
log_info "Dodaję wpisy do /etc/hosts..."
echo ""

if [ -n "$HOSTS_UPDATE" ]; then
    # używamy printf żeby zachować \n
    printf "%b" "$HOSTS_UPDATE" | sudo tee -a /etc/hosts >/dev/null
    log_info "/etc/hosts zaktualizowane."
else
    log_warn "Brak nowych wpisów do /etc/hosts (nie wybrano żadnych znanych node'ów?)."
fi

echo ""

# --- Generowanie klucza SSH (jeśli brak) ---
if [ ! -f ~/.ssh/id_rsa ]; then
    log_info "Generuję klucz SSH (bez hasła)..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
else
    log_info "Klucz SSH już istnieje — pomijam generowanie."
fi

echo ""
log_info "Dystrybucja klucza SSH na węzły (ssh-copy-id)..."

if [ "$USE_CONTROLLER" = true ]; then
    log_info "Kopiuję klucz na controller..."
    ssh-copy-id ubuntu@controller
fi

if [ "$USE_COMPUTE" = true ]; then
    log_info "Kopiuję klucz na compute..."
    ssh-copy-id ubuntu@compute
fi

if [ "$USE_STORAGE" = true ]; then
    log_info "Kopiuję klucz na storage..."
    ssh-copy-id ubuntu@storage
fi

CURRENT_USER="$(whoami)"

if [ "$USE_CONTROLLER" = true ]; then
    log_info "Dodawanie wpisu do /etc/sudoers..."
    echo "${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee -a /etc/sudoers
fi

if [ "$USE_COMPUTE" = true ]; then
    log_info "Dodawanie wpisu do /etc/sudoers..."
    ssh -t compute "echo '${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers"
fi

if [ "$USE_STORAGE" = true ]; then
    log_info "Dodawanie wpisu do /etc/sudoers..."
    ssh -t storage "echo '${CURRENT_USER} ALL=(ALL) NOPASSWD: ALL' | sudo tee -a /etc/sudoers"
fi

# --- Testy połączeń (na końcu, już po /etc/hosts) ---
echo ""
log_info "=== Testy połączeń sieciowych (ping) ==="

check_ping() {
    local HOST=$1
    if ping -c 3 "$HOST" >/dev/null 2>&1; then
        log_info "Połączenie z '$HOST' działa."
    else
        log_error "Brak połączenia z '$HOST'! Sprawdź /etc/hosts, sieć lub IP."
    fi
}

if [ "$USE_CONTROLLER" = true ]; then
    check_ping controller
fi
if [ "$USE_COMPUTE" = true ]; then
    check_ping compute
fi
if [ "$USE_STORAGE" = true ]; then
    check_ping storage
fi

echo ""
log_info "=== Zakończono konfigurację węzłów ==="