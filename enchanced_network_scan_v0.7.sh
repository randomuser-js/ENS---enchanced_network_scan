#!/bin/bash
# Mój 1 skrypt napisany przez ChatGPT- vibe coding - Wojtech

# nie działa!

print_color() {
    local color_code=$1
    shift
    echo -e "\e[${color_code}m$*\e[0m"
}

interface_type() {
    local interface=$1
    if iw dev "$interface" info &>/dev/null; then
        echo "Wi-Fi"
    elif [[ -d /sys/class/net/$interface ]]; then
        echo "LAN-Ethernet"
    else
        echo "Unknown"
    fi
}

default_gateway() {
    ip route | awk '/default/ {print $3}'
}

network_subnets() {
    ip -o -f inet addr show | awk '{print $2, $4}'
}

arp_scan() {
    local interface=$1
    arp-scan --interface="$interface" --localnet 2>/dev/null
}

nmap_scan() {
    local interface=$1
    local subnet=$(ip -o -f inet addr show "$interface" | awk '{print $4}')
    if [[ -n $subnet ]]; then
        print_color 36 "Rozpoczynanie skanowania Nmap na podsieci $subnet..."
        nmap -sn "$subnet" | grep "Nmap scan report" | awk '{print $NF " (" $5 ")"}'
    else
        print_color 31 "Nie można określić podsieci dla interfejsu $interface."
    fi
}

scan_incomplete_arp() {
    ip neigh | awk '/INCOMPLETE/ {print $1}'
}

get_hostname() {
    local ip=$1
    local hn=$(getent hosts "$ip" | awk '{print $2}')
    if [[ -z $hn ]]; then
        hn=$(nmblookup -A "$ip" 2>/dev/null | grep "<00>" | awk '{print $1}' | head -1)
    fi
    echo "${hn:-Unknown}"
}

get_router_info() {
    local gw_ip=$(default_gateway)
    local vendor="Unknown"
    local model="Unknown"
    local mac=$(arp -n | grep "$gw_ip" | awk '{print $3}')
    if [[ -n $mac ]]; then
        if command -v oui &>/dev/null; then
            vendor=$(oui "$mac" | head -1 | awk -F'\t' '{print $2}')
        fi
    fi
    echo "$gw_ip" "$vendor" "$model"
}

print_network_architecture() {
    # Ta funkcja pozostaje bez zmian z poprzedniej wersji.
}

main() {
    echo ""
    print_color 36 "Wykryto bramę domyślną:"
    local gw=$(default_gateway)
    if [[ -n $gw ]]; then
        print_color 32 "$gw"
    else
        print_color 31 "Brama domyślna nieznaleziona."
    fi

    echo ""
    print_color 36 "Wykryto podsieci:"
    local subs=$(network_subnets)
    if [[ -n $subs ]]; then
        echo "$subs"
    else
        print_color 31 "Nie znaleziono podsieci."
    fi

    echo ""
    print_color 36 "Informacje o dostępnych interfejsach sieciowych:"
    mapfile -t interfaces < <(ls /sys/class/net | grep -v lo)
    for iface in "${interfaces[@]}"; do
        type=$(interface_type "$iface")
        ip=$(ip -o -4 addr show "$iface" | awk '{print $4}')
        state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")

        case $type in
            "Wi-Fi") print_color 33 "$iface [$type] IP: $ip Status: $state" ;;
            "LAN-Ethernet") print_color 32 "$iface [$type] IP: $ip Status: $state" ;;
            *) print_color 31 "$iface [Unknown] IP: $ip Status: $state" ;;
        esac
    done

    echo ""
    while true; do
        read -e -p $'\e[33mPodaj nazwę interfejsu, który chcesz przeskanować (np. eth0): \e[0m' selected_iface
        if [[ " ${interfaces[*]} " == *" $selected_iface "* ]]; then
            break
        else
            print_color 31 "Niepoprawna nazwa interfejsu, spróbuj jeszcze raz."
        fi
    done

    print_color 33 "Wykonywanie skanowania ARP za pomocą arp-scan na interfejsie $selected_iface..."
    arp_scan "$selected_iface"

    echo ""
    print_color 33 "Wykonywanie skanowania sieci za pomocą Nmap na interfejsie $selected_iface..."
    nmap_scan "$selected_iface"

    echo ""
    print_color 36 "Wyszukiwanie urządzeń w sieci bez przypisanego adresu IP (incomplete ARP)..."
    scan_incomplete_arp

    print_network_architecture

    echo ""
    print_color 32 "Skanowanie zakończone."
}

main
