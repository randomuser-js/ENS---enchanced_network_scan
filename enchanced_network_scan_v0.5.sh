#!/bin/bash

# jest ok



# Sprawdzanie, czy użytkownik uruchomił skrypt z uprawnieniami administratora
if [[ $EUID -ne 0 ]]; then
    echo -e "\e[31mUruchom ten skrypt z uprawnieniami administratora (sudo).\e[0m" >&2
    exit 1
fi

# Funkcja do kolorowania wyjścia
print_color() {
    local color_code=$1
    shift
    echo -e "\e[${color_code}m$*\e[0m"
}

# Funkcja do automatycznego wykrycia bramy i podsieci
detect_network() {
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')
    print_color "32" "Wykryto bramę domyślną:"
    print_color "33" "$GATEWAY"
    echo ""
    print_color "32" "Wykryto podsieć:"
    print_color "33" "$SUBNET"
    echo ""
}

# Funkcja do sprawdzenia dostępności narzędzia
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        print_color "31" "Narzędzie $1 nie jest zainstalowane. Zainstaluj je, aby korzystać z pełnej funkcjonalności."
        exit 1
    fi
}

# Funkcja do pingowania urządzeń
ping_hosts() {
    print_color "36" "Pingowanie urządzeń w podsieci $SUBNET..."
    echo ""
    for ip in $(seq 1 254); do
        if ping -c 1 -W 1 "${SUBNET%.*}.$ip" &>/dev/null; then
            print_color "32" "Odpowiada: ${SUBNET%.*}.$ip"
        fi
    done
    echo ""
}

# Funkcja do skanowania ARP
arp_scan() {
    print_color "36" "Wykonywanie skanowania ARP za pomocą arp-scan..."
    echo ""
    arp-scan --interface="$1" --localnet | while read -r line; do
        print_color "33" "$line"
    done
    echo ""
}

# Funkcja do raportowania brakujących adresów IP
report_unconfigured() {
    print_color "36" "Wyszukiwanie urządzeń w sieci bez adresu IP (np. IoT devices,Raspberry Pi, Arduino,)..."
    echo ""
    UNCONFIGURED=$(arp -an | grep -i "incomplete")
    if [[ -z $UNCONFIGURED ]]; then
        print_color "32" "Nie znaleziono urządzeń bez przypisanego adresu IP."
    else
        print_color "33" "Urządzenia bez adresu IP:"
        echo "$UNCONFIGURED"
    fi
    echo ""
}

# Funkcja do rysowania architektury sieci
draw_network() {
    print_color "36" "Rysowanie architektury sieci w ASCII..."
    echo ""
    echo "Laptop 1"
    echo "   |"
    echo "   +---[LAN]---> Switch"
    echo "                 |"
    echo "                 +---[LAN]---> Raspberry Pi"
    echo "                 |"
    echo "                 +---[LAN]---> Laptop 2"
    echo ""
}

# Funkcja do wyświetlenia szczegółowych informacji o interfejsach
list_interfaces() {
    ip -o -f inet addr show | awk '
    {
        if ($2 != "lo") {
            print "\033[32mInterfejs:\033[0m", $2
            print "  \033[33mAdres IP:\033[0m", $4
            print "  \033[33mStatus:\033[0m", $9
        }
    }
    '
    echo ""
}


main() {
    detect_network

    # Sprawdzanie dostępności narzędzi
    check_tool "arp-scan"
    check_tool "ping"

    # Wyświetlenie szczegółowych informacji o interfejsach
    print_color "36" "Informacje o dostępnych interfejsach sieciowych:"
    echo ""
    list_interfaces

    # Użytkownik wybiera interfejs
    read -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE

    # Wykonanie skanowania ARP
    print_color "36" "Wyniki skanowania ARP:"
    arp_scan "$INTERFACE"

    # Pingowanie urządzeń
    ping_hosts

    # Raportowanie urządzeń bez adresu IP
    report_unconfigured

    # Rysowanie architektury sieci
    draw_network

    print_color "32" "Skanowanie zakończone."
}

# Uruchomienie głównej funkcji
main
