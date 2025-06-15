#!/bin/bash
#skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
#każdego hosta oraz wykryć nieznane hosty

#Changelog:
# 13.06.2005 - scan_result - usunięto

# Sprawdzanie, czy użytkownik uruchomił skrypt z uprawnieniami administratora
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom ten skrypt z uprawnieniami administratora (sudo)." >&2
    exit 1
fi

# Funkcja do automatycznego wykrycia bramy i podsieci
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

# Funkcja do sprawdzenia dostępności narzędzia
check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo ""
        echo "Narzędzie $1 nie jest zainstalowane."
        echo "Zainstaluj je, aby korzystać z pełnej funkcjonalności." >&2
        exit 1
    fi
}

# Funkcja do pingowania urządzeń
ping_hosts() {
    echo ""
    echo "Pingowanie urządzeń w podsieci $SUBNET..."
    echo ""
    for ip in $(seq 1 254); do
        ping -c 1 -W 1 "${SUBNET%.*}.$ip" &>/dev/null && echo "Odpowiada: ${SUBNET%.*}.$ip"
    done
    echo ""
}

# Funkcja do skanowania ARP
arp_scan() {
    echo ""
    echo "Wykonywanie skanowania ARP za pomocą arp-scan..."
    echo ""
    arp-scan --interface="$1" --localnet | while read -r line; do
        echo "$line"
    done
    echo ""
}

# Funkcja do raportowania brakujących adresów IP
report_unconfigured() {
    echo ""
    echo "Wyszukiwanie urządzeń w sieci bez adresu IP (np. Raspberry Pi)..."
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

# Funkcja do rysowania architektury sieci
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

# Funkcja do autouzupełniania interfejsów
get_interfaces_info() {
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
        print device, desc_type, desc_state, desc_mac
      }
      device=""; type=""; state=""; mac=""
    }
  '
}
#autocomplete_interface() {
#    echo ""
#    echo "Podpowiedź: Wciśnij TAB po wpisaniu pierwszej litery interfejsu."
#    echo ""
#    INTERFACES=$(nmcli -t -f DEVICE dev show | grep -v '^lo$')
#    complete -W "$INTERFACES" INTERFACE
#    read -e -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE

#    if ! echo "$INTERFACES" | grep -q "^$INTERFACE$"; then
#        echo ""
#        echo "Podany interfejs '$INTERFACE' nie istnieje lub jest niedostępny." >&2
#        exit 1
#    fi
#    echo ""
#}

# Główna logika skryptu
main() {
    detect_network

    # Sprawdzanie dostępności narzędzi
    check_tool "arp-scan"
    check_tool "ping"

    # Autouzupełnianie interfejsów
    autocomplete_interface

    # Wykonanie skanowania ARP
  #  echo "Wyniki skanowania ARP:"
  #  echo ""
  #  arp_scan "$INTERFACE"

    # Pingowanie urządzeń
   # echo "Pingowanie urządzeń:"
   # ping_hosts

    # Raportowanie urządzeń bez adresu IP
   # echo "Raport brakujących adresów IP:"
   # report_unconfigured

    # Rysowanie architektury sieci
   # draw_network

   # echo ""
   # echo "Skanowanie zakończone."
}

# Uruchomienie głównej funkcji
main

