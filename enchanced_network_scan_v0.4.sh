#!/bin/bash

# jest ok

# Sprawdzanie uprawnień root
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom ten skrypt z uprawnieniami administratora (sudo)." >&2
    exit 1
fi

# Automatyczne wykrycie bramy i podsieci
detect_network() {
    GATEWAY=$(ip route | grep default | awk '{print $3}')
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}')
    echo ""
    echo "Wykryto bramę domyślną:"
    echo "$GATEWAY"
    echo ""
    echo "Wykryto podsieć:"
    echo "$SUBNET"
    echo ""
}

# Sprawdzenie narzędzia w systemie
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo ""
        echo "Narzędzie $1 nie jest zainstalowane."
        echo "Zainstaluj je, aby korzystać z pełnej funkcjonalności." >&2
        exit 1
    fi
}

# Pingowanie hostów w podsieci (1-254)
ping_hosts() {
    echo ""
    echo "Pingowanie urządzeń w podsieci $SUBNET..."
    echo ""
    for ip in $(seq 1 254); do
        ping -c 1 -W 1 "${SUBNET%.*}.$ip" &>/dev/null && echo "Odpowiada: ${SUBNET%.*}.$ip"
    done
    echo ""
}

# Skanowanie ARP z wypisaniem każdej linii osobno
arp_scan() {
    echo ""
    echo "Wykonywanie skanowania ARP za pomocą arp-scan..."
    echo ""
    arp-scan --interface="$1" --localnet | while read -r line; do
        echo "$line"
    done
    echo ""
}

# Raport urządzeń z nieprzypisanym adresem IP (incomplete w arp)
report_unconfigured() {
    echo ""
    echo "Wyszukiwanie urządzeń w sieci bez przypisanego adresu IP (np. Raspberry Pi z problemami DHCP)..."
    echo ""
    UNCONFIGURED=$(arp -an | grep -i "incomplete")
    if [[ -z $UNCONFIGURED ]]; then
        echo "Nie znaleziono urządzeń bez przypisanego adresu IP."
    else
        echo "Urządzenia bez adresu IP:"
        echo "$UNCONFIGURED"
    fi
    echo ""
}

# Rysowanie prostej topologii ASCII
draw_network() {
    echo ""
    echo "Rysowanie architektury sieci w ASCII..."
    echo ""
    echo "Laptop 1"
    echo "   |"
    echo "   +---[LAN]---> Switch"
    echo "                 |"
    echo "                 +---[LAN]---> Raspberry Pi"
    echo ""
}

# Wyświetlanie interfejsów z ich typem, stanem i MAC
show_interfaces() {
    echo ""
    echo "Dostępne interfejsy sieciowe i ich status:"
    echo ""
    nmcli -f GENERAL.DEVICE,GENERAL.TYPE,GENERAL.STATE,GENERAL.HWADDR device show | awk '
    BEGIN { device=""; type=""; state=""; mac=""; OFS=" " }
    /^GENERAL.DEVICE:/ { device=$2 }
    /^GENERAL.TYPE:/ { type=$2 }
    /^GENERAL.STATE:/ { state=$2 }
    /^GENERAL.HWADDR:/ { mac=$2 }
    /^$/ {
      if(device!="") {
        desc_type="Typ nieznany"
        desc_state="Stan nieznany"
        desc_mac="MAC: brak"
        if(type=="ethernet") desc_type="Typ: interfejs przewodowy (Ethernet)"
        else if(type=="wifi") desc_type="Typ: interfejs bezprzewodowy (WiFi)"
        else if(type=="loopback") desc_type="Typ: pętla zwrotna (loopback)"
        else if(type=="bridge") desc_type="Typ: most sieciowy (bridge)"
        else desc_type="Typ: " type
        if(state=="100 (connected)") desc_state="Stan: podłączony"
        else if(state=="30 (disconnected)") desc_state="Stan: odłączony"
        else desc_state="Stan: " state
        if(mac!="") desc_mac="MAC: " mac " - karta sieciowa w obecnym urządzeniu"
        print device "\n" desc_type "\n" desc_state "\n" desc_mac "\n"
      }
      device=""; type=""; state=""; mac=""
    }
  '
}

# Główna logika
main() {
    detect_network

    check_tool "arp-scan"
    check_tool "ping"
    check_tool "nmcli"

    show_interfaces

    echo -n "Podaj nazwę interfejsu do skanowania (np. eth0): "
    read INTERFACE

    # Walidacja wpisanego interfejsu
    if ! nmcli device status | awk '{print $1}' | grep -qw "$INTERFACE"; then
        echo ""
        echo "Podany interfejs '$INTERFACE' nie istnieje lub jest niedostępny." >&2
        exit 1
    fi

    arp_scan "$INTERFACE"
    ping_hosts
    report_unconfigured
    draw_network

    echo ""
    echo "Skanowanie zakończone."
}

main
