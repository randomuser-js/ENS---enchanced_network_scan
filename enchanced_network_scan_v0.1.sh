#!/bin/bash
# v.01
# Sprawdzanie, czy użytkownik uruchomił skrypt z uprawnieniami administratora
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom ten skrypt z uprawnieniami administratora (sudo)." >&2
    exit 1
fi

# Funkcja do automatycznego wykrycia bramy i podsieci
detect_network() {
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')
    echo "Wykryto bramę domyślną: $GATEWAY"
    echo "Wykryto podsieć: $SUBNET"
    echo ""
}

# Funkcja do sprawdzenia dostępności narzędzia
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "Narzędzie $1 nie jest zainstalowane. Zainstaluj je, aby korzystać z pełnej funkcjonalności." >&2
        exit 1
    fi
}

# Funkcja do pingowania urządzeń
ping_hosts() {
    echo "Pingowanie urządzeń w podsieci $SUBNET..."
    for ip in $(seq 1 254); do
        ping -c 1 -W 1 "${SUBNET%.*}.$ip" &>/dev/null && echo "Odpowiada: ${SUBNET%.*}.$ip"
    done
}

# Funkcja do skanowania ARP
arp_scan() {
    echo "Wykonywanie skanowania ARP za pomocą arp-scan..."
    arp-scan --interface="$1" --localnet
}

# Funkcja do raportowania brakujących adresów IP
report_unconfigured() {
    echo "Wyszukiwanie urządzeń w sieci bez adresu IP (np. Raspberry Pi)..."
    UNCONFIGURED=$(arp -an | grep -i "incomplete")
    if [[ -z $UNCONFIGURED ]]; then
        echo "Nie znaleziono urządzeń bez przypisanego adresu IP."
    else
        echo "Urządzenia bez adresu IP:"
        echo "$UNCONFIGURED"
    fi
}

# Główna logika skryptu
main() {
    detect_network

    INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')
    echo "Dostępne interfejsy sieciowe:"
    echo "$INTERFACES"
    echo ""

    read -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE

    if ! echo "$INTERFACES" | grep -q "^$INTERFACE$"; then
        echo "Podany interfejs '$INTERFACE' nie istnieje lub jest niedostępny." >&2
        exit 1
    fi

    # Sprawdzanie dostępności narzędzi
    check_tool "arp-scan"
    check_tool "ping"

    # Wykonanie skanowania ARP
    RESULTS=$(arp_scan "$INTERFACE")
    echo ""
    echo "Wyniki skanowania ARP:"
    echo "$RESULTS"

    # Pingowanie urządzeń
    echo ""
    ping_hosts

    # Raportowanie urządzeń bez adresu IP
    echo ""
    report_unconfigured

    echo ""
    echo "Skanowanie zakończone."
}

# Uruchomienie głównej funkcji
main

