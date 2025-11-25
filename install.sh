#!/bin/bash
# OpenStack Kolla-Ansible Automated Installer
# Ubuntu 22.04 | Antelope (2023.1) | VirtualBox Setup
#
# Usage: ./install_openstack.sh [controller] [compute] [storage]
# Example: ./install_openstack.sh controller compute
# Example: ./install_openstack.sh controller compute storage

set -e

# Kolory dla outputu
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ścieżka do skryptu (katalog główny z konfiguracjami)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Sprawdź czy skrypt jest uruchamiany na Ubuntu 22.04
check_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Nie można określić systemu operacyjnego"
        exit 1
    fi
    
    . /etc/os-release
    if [[ "$ID" != "ubuntu" ]] || [[ "$VERSION_ID" != "22.04" ]]; then
        log_error "Ten skrypt wymaga Ubuntu 22.04"
        exit 1
    fi
    log_info "System operacyjny: Ubuntu 22.04 ✓"
}

# Parsowanie argumentów
parse_nodes() {
    if [ $# -eq 0 ]; then
        log_error "Musisz podać co najmniej jeden typ węzła!"
        echo "Użycie: $0 [controller] [compute] [storage]"
        echo "Przykład: $0 controller compute"
        exit 1
    fi
    
    HAS_CONTROLLER=false
    HAS_COMPUTE=false
    HAS_STORAGE=false
    
    for arg in "$@"; do
        case $arg in
            controller)
                HAS_CONTROLLER=true
                ;;
            compute)
                HAS_COMPUTE=true
                ;;
            storage)
                HAS_STORAGE=true
                ;;
            *)
                log_error "Nieznany typ węzła: $arg"
                echo "Dozwolone typy: controller, compute, storage"
                exit 1
                ;;
        esac
    done
    
    if [ "$HAS_CONTROLLER" = false ]; then
        log_error "Musisz zawrzeć przynajmniej węzeł 'controller'!"
        exit 1
    fi
    
    # Określ jaki jest deployment type
    if [ "$HAS_CONTROLLER" = true ] && [ "$HAS_COMPUTE" = true ] && [ "$HAS_STORAGE" = true ]; then
        DEPLOYMENT_TYPE="controller+compute+storage"
    elif [ "$HAS_CONTROLLER" = true ] && [ "$HAS_COMPUTE" = true ]; then
        DEPLOYMENT_TYPE="controller+compute"
    elif [ "$HAS_CONTROLLER" = true ]; then
        DEPLOYMENT_TYPE="controller"
    fi
    
    log_info "Konfiguracja węzłów:"
    echo "  - Controller: ${HAS_CONTROLLER}"
    echo "  - Compute: ${HAS_COMPUTE}"
    echo "  - Storage: ${HAS_STORAGE}"
    echo "  - Typ deploymentu: ${DEPLOYMENT_TYPE}"
}

# Zbieranie informacji o IP
gather_ip_info() {
    log_info "Zbieranie informacji o adresach IP..."
    
    # IP kontrolera
    read -p "Podaj IP węzła controller (domyślnie: 192.168.100.11): " CONTROLLER_IP
    CONTROLLER_IP=${CONTROLLER_IP:-192.168.100.11}
    
    # IP compute (jeśli istnieje)
    if [ "$HAS_COMPUTE" = true ]; then
        read -p "Podaj IP węzła compute (domyślnie: 192.168.100.12): " COMPUTE_IP
        COMPUTE_IP=${COMPUTE_IP:-192.168.100.12}
    fi
    
    # IP storage (jeśli istnieje)
    if [ "$HAS_STORAGE" = true ]; then
        read -p "Podaj IP węzła storage (domyślnie: 192.168.100.13): " STORAGE_IP
        STORAGE_IP=${STORAGE_IP:-192.168.100.13}
    fi
    
    # VIP
    read -p "Podaj VIP dla API (domyślnie: 192.168.100.254): " VIP_ADDRESS
    VIP_ADDRESS=${VIP_ADDRESS:-192.168.100.254}
    
    # Interfejs sieciowy
    read -p "Podaj interfejs zarządczy (domyślnie: enp0s8): " MGMT_INTERFACE
    MGMT_INTERFACE=${MGMT_INTERFACE:-enp0s8}
    
    read -p "Podaj interfejs zewnętrzny dla Neutron (domyślnie: enp0s9): " EXT_INTERFACE
    EXT_INTERFACE=${EXT_INTERFACE:-enp0s9}
    
    log_info "Podsumowanie konfiguracji sieci:"
    echo "  Controller IP: $CONTROLLER_IP"
    [ "$HAS_COMPUTE" = true ] && echo "  Compute IP: $COMPUTE_IP"
    [ "$HAS_STORAGE" = true ] && echo "  Storage IP: $STORAGE_IP"
    echo "  VIP: $VIP_ADDRESS"
    echo "  Interfejs zarządczy: $MGMT_INTERFACE"
    echo "  Interfejs zewnętrzny: $EXT_INTERFACE"
    
    read -p "Kontynuować z tą konfiguracją? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        log_error "Instalacja anulowana przez użytkownika"
        exit 1
    fi
}

# Sprawdzenie czy istnieją wymagane pliki konfiguracyjne
check_config_files() {
    log_info "Sprawdzanie dostępności plików konfiguracyjnych..."
    
    # Ścieżki do plików
    if [ "$DEPLOYMENT_TYPE" = "controller+compute+storage" ]; then
        GLOBALS_FILE="$SCRIPT_DIR/globals_configs/controller+compute+storage/globals.yml"
        MULTINODE_FILE="$SCRIPT_DIR/multinode_configs/compute+controller+storage/multinode"
    elif [ "$DEPLOYMENT_TYPE" = "controller+compute" ]; then
        GLOBALS_FILE="$SCRIPT_DIR/globals_configs/controller+compute/globals.yml"
        MULTINODE_FILE="$SCRIPT_DIR/multinode_configs/compute+controller/multinode"
    else
        GLOBALS_FILE="$SCRIPT_DIR/globals_configs/controller/globals.yml"
        MULTINODE_FILE="$SCRIPT_DIR/multinode_configs/controller/multinode"
    fi
    
    if [ ! -f "$GLOBALS_FILE" ]; then
        log_error "Nie znaleziono pliku: $GLOBALS_FILE"
        exit 1
    fi
    
    if [ ! -f "$MULTINODE_FILE" ]; then
        log_error "Nie znaleziono pliku: $MULTINODE_FILE"
        exit 1
    fi
    
    log_info "Pliki konfiguracyjne znalezione ✓"
    echo "  globals.yml: $GLOBALS_FILE"
    echo "  multinode: $MULTINODE_FILE"
}

# Instalacja pakietów systemowych
install_system_packages() {
    log_info "Instalacja pakietów systemowych..."
    sudo apt update
    sudo apt install -y python3-venv python3-dev gcc libffi-dev libssl-dev \
                        libyaml-dev libpq-dev git docker.io \
                        python3-pip python3-docker
    
    log_info "Konfiguracja Docker..."
    sudo systemctl enable docker
    sudo systemctl start docker
    sudo usermod -aG docker $USER
    
    log_info "Pakiety systemowe zainstalowane ✓"
}

# Konfiguracja virtualenv i Kolla-Ansible
setup_kolla_venv() {
    log_info "Konfiguracja virtualenv dla Kolla-Ansible..."
    
    sudo python3 -m venv /opt/kolla-venv
    sudo chown -R $USER:$USER /opt/kolla-venv
    source /opt/kolla-venv/bin/activate
    
    pip install -U pip
    pip install "ansible<8" "kolla-ansible==16.*" \
                python-openstackclient \
                python-heatclient
    
    log_info "Kolla-Ansible zainstalowany ✓"
    ansible --version
}

# Konfiguracja plików Kolla
setup_kolla_configs() {
    log_info "Kopiowanie plików konfiguracyjnych Kolla..."
    
    sudo mkdir -p /etc/kolla
    sudo chown -R $USER:$USER /etc/kolla
    
    source /opt/kolla-venv/bin/activate
    cp -r /opt/kolla-venv/share/kolla-ansible/etc_examples/kolla/* /etc/kolla
    
    log_info "Pliki konfiguracyjne skopiowane ✓"
}

# Kopiowanie gotowych plików konfiguracyjnych
copy_config_templates() {
    log_info "Kopiowanie gotowych szablonów konfiguracyjnych..."
    
    # Kopiuj globals.yml
    cp "$GLOBALS_FILE" /etc/kolla/globals.yml
    log_info "Skopiowano globals.yml ✓"
    
    # Kopiuj multinode
    cp "$MULTINODE_FILE" /etc/kolla/multinode
    log_info "Skopiowano multinode inventory ✓"
    
    # Opcjonalnie: podmień placeholdery IP w plikach (jeśli używasz)
    update_ip_placeholders
}

# Aktualizacja placeholderów IP w skopiowanych plikach
update_ip_placeholders() {
    log_info "Aktualizacja adresów IP w plikach konfiguracyjnych..."
    
    # Zamień placeholdery w multinode
    sed -i "s/CONTROLLER_IP/$CONTROLLER_IP/g" /etc/kolla/multinode
    
    if [ "$HAS_COMPUTE" = true ]; then
        sed -i "s/COMPUTE_IP/$COMPUTE_IP/g" /etc/kolla/multinode
    fi
    
    if [ "$HAS_STORAGE" = true ]; then
        sed -i "s/STORAGE_IP/$STORAGE_IP/g" /etc/kolla/multinode
    fi
    
    # Zamień placeholdery w globals.yml
    sed -i "s/VIP_ADDRESS/$VIP_ADDRESS/g" /etc/kolla/globals.yml
    sed -i "s/MGMT_INTERFACE/$MGMT_INTERFACE/g" /etc/kolla/globals.yml
    sed -i "s/EXT_INTERFACE/$EXT_INTERFACE/g" /etc/kolla/globals.yml
    
    log_info "Adresy IP zaktualizowane ✓"
}

# Generowanie inventory
generate_inventory() {
    log_info "Plik inventory został już skopiowany z szablonu"
    # Ta funkcja nie jest już potrzebna - zostaw jako placeholder
}

# Generowanie globals.yml
generate_globals() {
    log_info "Plik globals.yml został już skopiowany z szablonu"
    # Ta funkcja nie jest już potrzebna - zostaw jako placeholder
}

# Generowanie haseł
generate_passwords() {
    log_info "Generowanie haseł Kolla..."
    cd /etc/kolla
    source /opt/kolla-venv/bin/activate
    kolla-genpwd
    log_info "Hasła wygenerowane ✓"
}

# Konfiguracja /etc/hosts
configure_hosts() {
    log_info "Konfiguracja /etc/hosts..."
    
    # Usuń starą linię 127.0.1.1
    sudo sed -i '/127.0.1.1/d' /etc/hosts
    
    # Dodaj wpisy
    if ! grep -q "$CONTROLLER_IP.*controller" /etc/hosts; then
        echo "$CONTROLLER_IP   controller" | sudo tee -a /etc/hosts
    fi
    
    if [ "$HAS_COMPUTE" = true ]; then
        if ! grep -q "$COMPUTE_IP.*compute" /etc/hosts; then
            echo "$COMPUTE_IP   compute" | sudo tee -a /etc/hosts
        fi
    fi
    
    if [ "$HAS_STORAGE" = true ]; then
        if ! grep -q "$STORAGE_IP.*storage" /etc/hosts; then
            echo "$STORAGE_IP   storage" | sudo tee -a /etc/hosts
        fi
    fi
    
    log_info "/etc/hosts skonfigurowany ✓"
}

# Instalacja zależności Ansible
install_ansible_deps() {
    log_info "Instalacja zależności Ansible..."
    source /opt/kolla-venv/bin/activate
    kolla-ansible install-deps
    log_info "Zależności Ansible zainstalowane ✓"
}

# Bootstrap serwerów
bootstrap_servers() {
    log_info "Bootstrap serwerów..."
    source /opt/kolla-venv/bin/activate
    
    if ! kolla-ansible -i /etc/kolla/multinode bootstrap-servers; then
        log_error "Bootstrap nie powiódł się. Sprawdź Docker na wszystkich węzłach."
        log_info "Próba naprawy Docker..."
        sudo apt install --reinstall -y docker.io
        sudo systemctl restart docker
        
        log_info "Ponawianie bootstrap..."
        kolla-ansible -i /etc/kolla/multinode bootstrap-servers
    fi
    
    log_info "Bootstrap zakończony ✓"
}

# Prechecks
run_prechecks() {
    log_info "Uruchamianie prechecks..."
    source /opt/kolla-venv/bin/activate
    kolla-ansible -i /etc/kolla/multinode prechecks
    log_info "Prechecks zakończone ✓"
}

# Deploy OpenStack
deploy_openstack() {
    log_info "Rozpoczynam deploy OpenStack (to może potrwać 20-40 minut)..."
    source /opt/kolla-venv/bin/activate
    kolla-ansible -i /etc/kolla/multinode deploy
    log_info "Deploy OpenStack zakończony ✓"
}

# Post-deploy
post_deploy() {
    log_info "Uruchamianie post-deploy..."
    source /opt/kolla-venv/bin/activate
    kolla-ansible post-deploy
    
    # Konfiguracja clouds.yaml
    mkdir -p ~/.config/openstack
    sudo cp /etc/kolla/clouds.yaml ~/.config/openstack/
    sudo chown -R $USER:$USER ~/.config/openstack
    
    log_info "Post-deploy zakończony ✓"
}

# Wyświetlenie informacji końcowych
display_summary() {
    log_info "==================================="
    log_info "INSTALACJA ZAKOŃCZONA POMYŚLNIE!"
    log_info "==================================="
    echo ""
    
    ADMIN_PASSWORD=$(grep keystone_admin_password /etc/kolla/passwords.yml | awk '{print $2}')
    
    echo "URL Horizon: http://$VIP_ADDRESS/"
    echo "Login: admin"
    echo "Hasło: $ADMIN_PASSWORD"
    echo ""
    echo "Aby sprawdzić status OpenStack:"
    echo "  source /opt/kolla-venv/bin/activate"
    echo "  openstack --os-cloud kolla-admin service list"
    echo "  openstack --os-cloud kolla-admin orchestration service list"
    echo ""
    
    if [ "$HAS_COMPUTE" = false ]; then
        log_warn "Uwaga: Nie dodano osobnego węzła compute. Wszystko działa na controllerze."
    fi
    
    log_info "Pamiętaj o skonfigurowaniu sieci w /etc/netplan/ na wszystkich węzłach!"
}

# Główna funkcja
main() {
    log_info "OpenStack Kolla-Ansible - Automatyczna Instalacja"
    log_info "==================================================="
    echo ""
    
    check_os
    parse_nodes "$@"
    check_config_files
    gather_ip_info
    
    echo ""
    read -p "Rozpocząć instalację? (y/n): " START
    if [[ "$START" != "y" && "$START" != "Y" ]]; then
        log_error "Instalacja anulowana"
        exit 1
    fi
    
    install_system_packages
    setup_kolla_venv
    setup_kolla_configs
    copy_config_templates
    generate_passwords
    configure_hosts
    install_ansible_deps
    bootstrap_servers
    run_prechecks
    deploy_openstack
    post_deploy
    display_summary
}

# Uruchom główną funkcję z argumentami
main "$@"