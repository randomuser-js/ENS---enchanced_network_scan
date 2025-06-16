#!/bin/bash

# skrypt ma błędy i niepotrzebnie pinguje wszystkie wolne IP. 

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

# Funkcja do sprawdzenia poprawności interfejsu
validate_interface() {
    local interface=$1
    if [[ ! -d "/sys/class/net/$interface" ]]; then
        print_color "31" "Nie znaleziono interfejsu: $interface. Podaj poprawną nazwę."
        return 1
    fi
    return 0
}

# Funkcja do wykrywania typu interfejsu
interface_type() {
    local interface=$1
    if [[ $interface == en* ]]; then
        echo "LAN-Ethernet"
    elif [[ $interface == wl* ]]; then
        echo "Wi-Fi"
    else
        echo "Nieznany typ"
    fi
}

# Funkcja do automatycznego wykrycia bramy i podsieci
detect_network() {
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4 " " $2}')
    print_color "32" "Wykryto bramę domyślną:"
    print_color "33" "$GATEWAY"
    echo ""
    print_color "32" "Wykryto podsieć:"
    while read -r subnet iface; do
        print_color "33" "$subnet ($iface)"
    done <<< "$SUBNET"
    echo ""
    if [[ $(echo "$SUBNET" | wc -l) -gt 1 ]]; then
        print_color "31" "Wykryto potencjalny konflikt adresów podsieci:"
        while read -r subnet iface; do
            print_color "33" "$subnet ($iface)"
        done <<< "$SUBNET"
        print_color "31" "Zalecenie: Ustaw spójne adresy IP i maski w jednym zakresie podsieci."
    fi
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
    while read -r subnet iface; do
        print_color "36" "Pingowanie urządzeń w podsieci $subnet ($iface)..."
        echo ""
        fping -a -g "$subnet" 2>/dev/null || print_color "31" "Nie udało się pingować urządzeń w podsieci $subnet ($iface)."
    done <<< "$SUBNET"
    echo ""
}

# Funkcja do skanowania ARP
arp_scan() {
    print_color "36" "Wykonywanie skanowania ARP za pomocą arp-scan..."
    echo ""
    if ! sudo arp-scan --interface="$1" --localnet; then
        print_color "31" "Błąd podczas skanowania ARP. Upewnij się, że interfejs działa poprawnie."
    fi
    echo ""
}

# Funkcja do raportowania brakujących adresów IP
report_unconfigured() {
    print_color "36" "Wyszukiwanie urządzeń w sieci bez adresu IP (np. IoT devices, Raspberry Pi, Arduino,)..."
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

# Funkcja do wyświetlenia szczegółowych informacji o interfejsach
list_interfaces() {
    ip -o -f inet addr show | awk '
    {
        if ($2 != "lo") {
            printf "\033[32mInterfejs:\033[0m %s\n  \033[33mAdres IP:\033[0m %s\n  \033[33mStatus:\033[0m %s\n", $2, $4, $6
            printf "  \033[33mTyp:\033[0m %s\n", system("bash -c \"source $0; interface_type $2\"")
        }
    }
    '
    echo ""
}

main() {
    detect_network

    # Sprawdzanie dostępności narzędzi
    check_tool "arp-scan"
    check_tool "fping"

    # Wyświetlenie szczegółowych informacji o interfejsach
    print_color "36" "Informacje o dostępnych interfejsach sieciowych:"
    echo ""
    list_interfaces

    # Użytkownik wybiera interfejs
    read -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE
    while ! validate_interface "$INTERFACE"; do
        read -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE
    done

    # Wykonanie skanowania ARP
    print_color "36" "Wyniki skanowania ARP:"
    arp_scan "$INTERFACE"

    # Pingowanie urządzeń
    ping_hosts

    # Raportowanie urządzeń bez adresu IP
    report_unconfigured

    print_color "32" "Skanowanie zakończone."
}

# Uruchomienie głównej funkcji
main
