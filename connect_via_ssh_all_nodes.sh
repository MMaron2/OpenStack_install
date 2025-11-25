#!/bin/bash

echo "=== Konfiguracja węzłów OpenStack ==="
echo ""

check_ping() {
    local HOST=$1
    if ping -c 3 "$HOST" >/dev/null 2>&1; then
        log_info "Połączenie z '$HOST' działa."
    else
        log_error "Brak połączenia z '$HOST'! Sprawdź /etc/hosts, sieć lub IP."
    fi
}

echo ""
echo "testy połączenia z węzłami"

check_ping controller
check_ping compute
check_ping storage

# --- Pobranie adresów IP ---
read -p "Podaj adres IP dla CONTROLLER: " IP_CONTROLLER
read -p "Podaj adres IP dla COMPUTE: " IP_COMPUTE
read -p "Podaj adres IP dla STORAGE: " IP_STORAGE

echo ""
echo "Dodaję wpisy do /etc/hosts..."
echo ""

# --- Dodawanie wpisów do /etc/hosts ---
sudo bash -c "cat >> /etc/hosts" <<EOF
$IP_CONTROLLER   controller
$IP_COMPUTE      compute
$IP_STORAGE      storage
EOF

echo "Wpisy zostały dodane."
echo ""

# --- Generowanie klucza SSH (jeśli brak) ---
if [ ! -f ~/.ssh/id_rsa ]; then
    echo "Generuję klucz SSH..."
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
else
    echo "Klucz SSH już istnieje — pomijam generowanie."
fi

echo ""
echo "Dystrybucja klucza SSH na węzły:"

# --- Kopiowanie klucza na węzły ---
ssh-copy-id ubuntu@controller
ssh-copy-id ubuntu@compute
ssh-copy-id ubuntu@storage

echo ""
echo "=== Zakończono konfigurację ==="
