#!/bin/bash
# Mój 1 skrypt napisany przez ChatGPT- vibe coding - Wojtech

#słaby!

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

# Próba wyciągnięcia modelu i producenta routera z ARP lub innych metod (bardzo często nieosiągalne)
get_router_info() {
    local gw_ip=$(default_gateway)
    local vendor="Unknown"
    local model="Unknown"
    # Próbujemy z `arp -n` i `grep` - bardzo prymitywne
    local mac=$(arp -n | grep "$gw_ip" | awk '{print $3}')
    if [[ -n $mac ]]; then
        # Vendor z OUI (jeśli masz zainstalowane narzędzie "oui")
        if command -v oui &>/dev/null; then
            vendor=$(oui "$mac" | head -1 | awk -F'\t' '{print $2}')
        fi
    fi
    echo "$gw_ip" "$vendor" "$model"
}

# Autouzupełnianie interfejsów do read
_autocomplete_interfaces() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    COMPREPLY=( $(compgen -W "$(ls /sys/class/net | grep -v lo)" -- "$cur") )
}

print_network_architecture() {
    local interfaces iface type ip state ssid label
    local i=0
    declare -a wifi_labels lan_labels

    mapfile -t interfaces < <(ls /sys/class/net | grep -v lo)

    # Oddziel interfejsy Wi-Fi i LAN
    for iface in "${interfaces[@]}"; do
        type=$(interface_type "$iface")
        ip=$(ip -o -4 addr show "$iface" | awk '{print $4}' || echo "Brak IP")
        state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")

        if [[ $type == "Wi-Fi" ]]; then
            ssid=$(iw dev "$iface" link | awk '/SSID/ {print $2}')
            [[ -z $ssid ]] && ssid="Brak SSID"
            label="$iface [$type] SSID: $ssid IP: $ip Status: $state"
            wifi_labels[i++]="$label"
        elif [[ $type == "LAN-Ethernet" ]]; then
            label="$iface [$type] IP: $ip Status: $state"
            lan_labels[i++]="$label"
        else
            label="$iface [Unknown] IP: $ip Status: $state"
            print_color 31 "Nieznany interfejs: $label"
        fi
    done

    # Rysowanie sieci Wi-Fi
    echo ""
    print_color 36 "Rysowanie architektury sieci Wi-Fi w ASCII..."
    echo ""

    local padding=38
    local router_info=($(get_router_info))
    local gw_ip="${router_info[0]}"
    local gw_vendor="${router_info[1]}"
    local gw_model="${router_info[2]}"

    printf "%${padding}s\n" "[Internet]"
    printf "%${padding}s\n" "    |"
    print_color 35 "$(printf "%${padding}s\n" "[Router]")"
    print_color 35 "$(printf "%${padding}s\n" "IP: $gw_ip")"
    print_color 35 "$(printf "%${padding}s\n" "Producent: $gw_vendor")"
    print_color 35 "$(printf "%${padding}s\n" "Model: $gw_model")"

    if [[ ${#wifi_labels[@]} -gt 0 ]]; then
        print_color 33 "|--> ${wifi_labels[0]}"
        printf "%${padding}s\n" "   /|\\"
        printf "%${padding}s\n" "  / | \\"

        local wifi_iface=$(echo "${wifi_labels[0]}" | awk '{print $1}')
        mapfile -t wifi_arp < <(arp_scan "$wifi_iface" | awk 'NR>2 {print $1}' | grep -v "Interface")

        if [[ ${#wifi_arp[@]} -eq 0 ]]; then
            print_color 33 "  (Brak urządzeń Wi-Fi do wyświetlenia)"
        else
            for ip_addr in "${wifi_arp[@]}"; do
                hn=$(get_hostname "$ip_addr")
                print_color 33 "  $hn ($ip_addr)"
            done
        fi
    else
        echo "|-->"
        printf "%${padding}s\n" "   /|\\"
        printf "%${padding}s\n" "  / | \\"
        print_color 33 "  (Brak urządzeń Wi-Fi do wyświetlenia)"
    fi

    # Rysowanie sieci LAN
    echo ""
    print_color 36 "Rysowanie architektury sieci LAN w ASCII..."
    echo ""

    if [[ ${#lan_labels[@]} -gt 0 ]]; then
        for label in "${lan_labels[@]}"; do
            print_color 32 "|--> $label"
        done
    else
        print_color 31 "Brak interfejsów LAN do wyświetlenia."
    fi

    # Prosty schemat LAN (statyczny switch, bo wykrycie go wymaga SNMP i sprzętu)
    echo ""
    print_color 36 "Prosty schemat podsieci LAN:"
    echo ""

    if [[ ${#lan_labels[@]} -gt 0 ]]; then
        local lan_iface=$(echo "${lan_labels[0]}" | awk '{print $1}')
        print_color 32 "Laptop 1 (ten komputer)"
        print_color 32 "   |"
        print_color 35 "   +---[LAN]---> Switch (Producent: Unknown, Model: Unknown)"
        print_color 32 "                 |"

        mapfile -t arp_devices < <(arp_scan "$lan_iface" | awk 'NR>2 {print $1}' | grep -v "Interface")

        if [[ ${#arp_devices[@]} -eq 0 ]]; then
            print_color 31 "Brak urządzeń LAN do wyświetlenia schematu."
        else
            for ip_addr in "${arp_devices[@]}"; do
                hn=$(get_hostname "$ip_addr")
                print_color 32 "                 +---[LAN]---> $hn ($ip_addr)"
            done
        fi
    else
        print_color 31 "Brak interfejsów LAN do wyświetlenia schematu."
    fi

    echo ""
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
    print_color 31 "Wykryto potencjalny konflikt adresów podsieci:"
    local conflicts=$(network_subnets | awk '{print $2}' | sort | uniq -d)
    if [[ -z $conflicts ]]; then
        print_color 32 "Brak konfliktów adresów podsieci."
    else
        echo "$conflicts"
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
    if [[ $- == *i* ]]; then
        complete -F _autocomplete_interfaces scan_iface_completion 2>/dev/null
    fi

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
    print_color 36 "Wyszukiwanie urządzeń w sieci bez przypisanego adresu IP (incomplete ARP)..."
    scan_incomplete_arp

    print_network_architecture

    echo ""
    print_color 32 "Skanowanie zakończone."
}

main
