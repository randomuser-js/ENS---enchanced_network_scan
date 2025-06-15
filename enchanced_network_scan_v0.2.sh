#!/bin/bash
#skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
#każdego hosta oraz wykryć nieznane hosty
#Changelog:
# 13.06.2005 - Zapisuje wyniki do scan_result.txt

# Sprawdzanie, czy użytkownik uruchomił skrypt z uprawnieniami administratora
if [[ $EUID -ne 0 ]]; then
    echo "Uruchom ten skrypt z uprawnieniami administratora (sudo)." >&2
    exit 1
fi

# Pobranie listy aktywnych interfejsów sieciowych
INTERFACES=$(ip -o link show | awk -F': ' '{print $2}')

echo "Wykryte interfejsy sieciowe:"
echo "$INTERFACES"
echo ""

# Wybranie interfejsu do skanowania
read -p "Podaj nazwę interfejsu, który chcesz przeskanować (np. eth0): " INTERFACE

# Sprawdzenie, czy podany interfejs istnieje
if ! echo "$INTERFACES" | grep -q "^$INTERFACE$"; then
    echo "Podany interfejs '$INTERFACE' nie istnieje lub jest niedostępny." >&2
    exit 1
fi

# Wykonanie skanowania sieci za pomocą arp-scan
echo "Skanowanie sieci na interfejsie $INTERFACE..."
sudo arp-scan --interface="$INTERFACE" --localnet | tee scan_result.txt

echo ""
echo "Skanowanie zakończone. Wyniki zapisano w pliku scan_result.txt."

