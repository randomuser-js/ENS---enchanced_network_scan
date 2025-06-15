#!/bin/bash
# skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
# każdego hosta oraz wykryć nieznane hosty
# Skrypt skanuje dostepne sieci podaje jej parametry IP, Brama, adres MAC urzadzenia, na koniec rysuje prosta grafikę w ASCII.

# Mój 1 skrypt napisany przez ChatGPT- vibe coding - oraz claude.AI - Wojtech
# 14.06.2025:
# Naprawiona wersja z zaktualizowaną bazą danych MAC OUI dla Rasberry Pi, Arduino i urządzeń IoT -

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

# Funkcja do identyfikacji urządzeń IoT na podstawie adresu MAC
identify_device_type() {
local mac=$1
local ip=$2
local device_type="Unknown"
local color_code="37" # szary dla ogólnych

# Aktualne prefiksy MAC Raspberry Pi (2024-2025)
local raspi_prefixes=(
    "28:CD:C1"  # Raspberry Pi Trading Ltd
    "2C:CF:67"  # Raspberry Pi Trading Ltd  
    "B8:27:EB"  # Raspberry Pi Foundation (oryginalny)
    "D8:3A:DD"  # Raspberry Pi Trading Ltd
    "DC:A6:32"  # Raspberry Pi Trading Ltd
    "E4:5F:01"  # Raspberry Pi Trading Ltd
)

# Arduino/ESP MAC prefixes (Espressif Systems - aktualizowane 2024-2025)
local arduino_prefixes=(
    "24:0A:C4"  # Espressif Inc
    "30:AE:A4"  # Espressif Inc
    "84:CC:A8"  # Espressif Inc
    "8C:AA:B5"  # Espressif Inc
    "A0:20:A6"  # Espressif Inc
    "CC:50:E3"  # Espressif Inc
    "DC:4F:22"  # Espressif Inc
    "EC:FA:BC"  # Espressif Inc
    "24:D7:EB"  # Espressif Inc
    "34:86:5D"  # Espressif Inc
    "68:C6:3A"  # Espressif Inc
    "A4:CF:12"  # Espressif Inc
    "C8:C9:A3"  # Espressif Inc
    "24:6F:28"  # Espressif Inc (nowy 2024)
    "58:BF:25"  # Espressif Inc
    "94:B9:7E"  # Espressif Inc
    "C0:49:EF"  # Espressif Inc
    "E8:DB:84"  # Espressif Inc
    "3C:61:05"  # Espressif Inc
    "40:F5:20"  # Espressif Inc
    "78:21:84"  # Espressif Inc
    "FC:F5:C4"  # Espressif Inc
)

# Sprawdź Raspberry Pi
for prefix in "${raspi_prefixes[@]}"; do
    if [[ ${mac^^} == ${prefix}* ]]; then
        device_type="Raspberry Pi"
        color_code="95" # malinowy (jasny magenta)
        break
    fi
done

# Sprawdź Arduino/ESP jeśli nie znaleziono Raspberry Pi
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${arduino_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="Arduino/ESP"
            color_code="34" # niebieski
            break
        fi
    done
fi

echo "$device_type:$color_code"
}

get_hostname() {
local ip=$1
local hn=$(getent hosts "$ip" | awk '{print $2}')
if [[ -z $hn ]]; then
    hn=$(nmblookup -A "$ip" 2>/dev/null | grep "<00>" | awk '{print $1}' | head -1)
fi
echo "${hn:-Unknown}"
}

# Próba wyciągnięcia modelu i producenta routera z ARP lub innych metod
get_router_info() {
local gw_ip=$(default_gateway)
local vendor="Unknown"
local model="Unknown"
# Próbujemy z arp -n i grep - bardzo prymitywne
local mac=$(arp -n | grep "$gw_ip" | awk '{print $3}')
if [[ -n $mac ]]; then
    # Vendor z OUI (jeśli masz zainstalowane narzędzie "oui")
    if command -v oui &>/dev/null; then
        vendor=$(oui "$mac" | head -1 | awk -F'\t' '{print $2}')
    fi
fi
echo "$gw_ip" "$vendor" "$model"
}

# Funkcja do parsowania wyników arp-scan i zwracania IP i MAC z identyfikacją urządzeń
parse_arp_scan_results() {
local interface=$1
arp-scan --interface="$interface" --localnet 2>/dev/null | awk 'NR>2 && !/^Interface/ && !/^Starting/ && !/^Ending/ && !/packets/ && NF>=2 {print $1 ":" $2}'
}

# Funkcja skanowania IoT urządzeń (Raspberry Pi i Arduino)
scan_iot_devices() {
local interfaces iface type
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "=== SKANOWANIE URZĄDZEŃ IoT (Raspberry Pi, Arduino/ESP) ==="
echo ""

local found_iot=false

for iface in "${all_interfaces[@]}"; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    if [[ $state == "up" ]]; then
        print_color 36 "Skanowanie interfejsu: $iface"
        mapfile -t devices < <(parse_arp_scan_results "$iface")
        for device in "${devices[@]}"; do
            if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                local ip_addr=$(echo "$device" | cut -d':' -f1)
                local mac_addr=$(echo "$device" | cut -d':' -f2-)
                if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                    local color_code=$(echo "$device_info" | cut -d':' -f2)

                    # Wyświetl TYLKO urządzenia IoT (Raspberry Pi i Arduino/ESP)
                    if [[ $device_type == "Raspberry Pi" || $device_type == "Arduino/ESP" ]]; then
                        local hn=$(get_hostname "$ip_addr")
                        print_color "$color_code" "✓ ZNALEZIONO $device_type: $hn (IP: $ip_addr ; MAC: $mac_addr)"
                        found_iot=true
                    fi
                fi
            fi
        done
    fi
done

if [[ $found_iot == false ]]; then
    print_color 31 "✗ Brak urządzeń IoT (Raspberry Pi/Arduino) w sieci"
fi

echo ""
print_color 36 "Znane prefiksy MAC dla urządzeń IoT:"
print_color 95 "Raspberry Pi: 28:CD:C1, 2C:CF:67, B8:27:EB, D8:3A:DD, DC:A6:32, E4:5F:01"
print_color 34 "Arduino/ESP: 24:0A:C4, 30:AE:A4, 84:CC:A8, 8C:AA:B5, A0:20:A6, CC:50:E3, DC:4F:22, EC:FA:BC"
echo ""
}

# Funkcja skanowania nierozpoznanych urządzeń
scan_unknown_devices() {
local interfaces iface type
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "=== SKANOWANIE NIEROZPOZNANYCH URZĄDZEŃ ==="
echo ""

local found_unknown=false

for iface in "${all_interfaces[@]}"; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    if [[ $state == "up" ]]; then
        print_color 36 "Skanowanie interfejsu: $iface"
        mapfile -t devices < <(parse_arp_scan_results "$iface")
        for device in "${devices[@]}"; do
            if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                local ip_addr=$(echo "$device" | cut -d':' -f1)
                local mac_addr=$(echo "$device" | cut -d':' -f2-)
                if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                    local color_code=$(echo "$device_info" | cut -d':' -f2)

                    # Wyświetl tylko nierozpoznane urządzenia
                    if [[ $device_type == "Unknown" ]]; then
                        local hn=$(get_hostname "$ip_addr")
                        print_color "$color_code" "? NIEROZPOZNANE: $hn (IP: $ip_addr ; MAC: $mac_addr)"
                        found_unknown=true
                    fi
                fi
            fi
        done
    fi
done

if [[ $found_unknown == false ]]; then
    print_color 32 "✓ Wszystkie urządzenia w sieci są rozpoznane"
fi
echo ""
}

# Funkcja wyświetlania informacji o wszystkich urządzeniach
show_all_devices() {
local interfaces iface type
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "=== WSZYSTKIE WYKRYTE URZĄDZENIA W SIECI ==="
echo ""

local found_any=false

for iface in "${all_interfaces[@]}"; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    if [[ $state == "up" ]]; then
        print_color 36 "Interfejs: $iface ($(interface_type "$iface"))"
        mapfile -t devices < <(parse_arp_scan_results "$iface")
        for device in "${devices[@]}"; do
            if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                local ip_addr=$(echo "$device" | cut -d':' -f1)
                local mac_addr=$(echo "$device" | cut -d':' -f2-)
                if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                    local color_code=$(echo "$device_info" | cut -d':' -f2)
                    local hn=$(get_hostname "$ip_addr")
                    
                    print_color "$color_code" "  → $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                    found_any=true
                fi
            fi
        done
        echo ""
    fi
done

if [[ $found_any == false ]]; then
    print_color 31 "Brak urządzeń do wyświetlenia"
fi
}

print_network_architecture() {
local interfaces iface type ip state ssid label
local i=0
declare -a wifi_labels lan_labels wifi_interfaces lan_interfaces

mapfile -t interfaces < <(ls /sys/class/net | grep -v lo)

# Oddziel interfejsy Wi-Fi i LAN
for iface in "${interfaces[@]}"; do
    type=$(interface_type "$iface")
    ip=$(ip -o -4 addr show "$iface" | awk '{print $4}' || echo "Brak IP")
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")

    if [[ $type == "Wi-Fi" ]]; then
        ssid=$(iw dev "$iface" link 2>/dev/null | awk '/SSID/ {print $2}')
        [[ -z $ssid ]] && ssid="Brak SSID"
        label="$iface [$type] SSID: $ssid IP: $ip Status: $state"
        wifi_labels[i]="$label"
        wifi_interfaces[i]="$iface"
        ((i++))
    elif [[ $type == "LAN-Ethernet" ]]; then
        label="$iface [$type] IP: $ip Status: $state"
        lan_labels[${#lan_labels[@]}]="$label"
        lan_interfaces[${#lan_interfaces[@]}]="$iface"
    fi
done

echo ""
print_color 36 "=== SCHEMAT ARCHITEKTURY SIECI Wi-Fi ==="
echo ""

local padding=38
local router_info=($(get_router_info))
local gw_ip="${router_info[0]}"
local gw_vendor="${router_info[1]}"
local gw_model="${router_info[2]}"

printf "%${padding}s\n" "[Internet]"
printf "%${padding}s\n" " |"
print_color 35 "$(printf "%${padding}s\n" "[Router/Gateway]")"
print_color 35 "$(printf "%${padding}s\n" "IP: $gw_ip")"
print_color 35 "$(printf "%${padding}s\n" "Producent: $gw_vendor")"
print_color 35 "$(printf "%${padding}s\n" "Model: $gw_model")"

if [[ ${#wifi_labels[@]} -gt 0 ]]; then
    print_color 33 "|--> ${wifi_labels[0]}"
    printf "%${padding}s\n" "  /|\\"
    printf "%${padding}s\n" " / | \\"
    printf "%${padding}s\n" "/   |   \\"

    # Skanowanie urządzeń Wi-Fi w czasie rzeczywistym
    local wifi_found=false
    for wifi_iface in "${wifi_interfaces[@]}"; do
        if [[ -n $wifi_iface ]]; then
            state=$(cat /sys/class/net/"$wifi_iface"/operstate 2>/dev/null || echo "unknown")
            if [[ $state == "up" ]]; then
                mapfile -t wifi_devices < <(parse_arp_scan_results "$wifi_iface")
                if [[ ${#wifi_devices[@]} -gt 0 ]]; then
                    wifi_found=true
                    for device in "${wifi_devices[@]}"; do
                        if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                            local ip_addr=$(echo "$device" | cut -d':' -f1)
                            local mac_addr=$(echo "$device" | cut -d':' -f2-)
                            local hn=$(get_hostname "$ip_addr")
                            if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                                local device_type=$(echo "$device_info" | cut -d':' -f1)
                                local color_code=$(echo "$device_info" | cut -d':' -f2)

                                print_color "$color_code" " $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                            fi
                        fi
                    done
                fi
            fi
        fi
    done

    if [[ $wifi_found == false ]]; then
        print_color 33 " (Brak aktywnych urządzeń Wi-Fi)"
    fi
else
    # Naprawiony wzór fali Wi-Fi - lepiej wyjustowany z 3 liniami
    printf "%${padding}s\n" "|-->"
    printf "%${padding}s\n" "  /|\\"
    printf "%${padding}s\n" " / | \\"
    printf "%${padding}s\n" "/   |   \\"
    print_color 33 " (Brak interfejsów Wi-Fi)"
fi

echo ""
print_color 36 "=== SCHEMAT ARCHITEKTURY SIECI LAN ==="
echo ""

if [[ ${#lan_labels[@]} -gt 0 ]]; then
    # Pobierz informacje o tym komputerze
    local this_hostname=$(hostname)
    local this_ip=""
    local this_mac=""
    
    if [[ ${#lan_interfaces[@]} -gt 0 && -n ${lan_interfaces[0]} ]]; then
        this_ip=$(ip -o -4 addr show "${lan_interfaces[0]}" 2>/dev/null | awk '{print $4}' | cut -d'/' -f1)
        this_mac=$(ip link show "${lan_interfaces[0]}" 2>/dev/null | awk '/ether/ {print $2}')
    fi
    
    # Schemat w stylu poprzedniej wersji
    print_color 32 "Gospodarz (ten komputer) $this_hostname (IP: ${this_ip:-Unknown} : MAC: ${this_mac:-Unknown})"
    print_color 35 "                     |"
    print_color 35 "        Switch (Producent: Unknown, Model: Unknown)"
    print_color 35 "                     |"

    # Skanowanie urządzeń LAN w czasie rzeczywistym
    local lan_found=false
    for lan_iface in "${lan_interfaces[@]}"; do
        if [[ -n $lan_iface ]]; then
            state=$(cat /sys/class/net/"$lan_iface"/operstate 2>/dev/null || echo "unknown")
            if [[ $state == "up" ]]; then
                mapfile -t lan_devices < <(parse_arp_scan_results "$lan_iface")
                if [[ ${#lan_devices[@]} -gt 0 ]]; then
                    lan_found=true
                    for device in "${lan_devices[@]}"; do
                        if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                            local ip_addr=$(echo "$device" | cut -d':' -f1)
                            local mac_addr=$(echo "$device" | cut -d':' -f2-)
                            if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                # Pomiń ten komputer (host) w liście urządzeń
                                if [[ $ip_addr != $this_ip ]]; then
                                    local hn=$(get_hostname "$ip_addr")
                                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                                    local color_code=$(echo "$device_info" | cut -d':' -f2)
                                    
                                    print_color "$color_code" "            $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                                fi
                            fi
                        fi
                    done
                fi
            fi
        fi
    done

    if [[ $lan_found == false ]]; then
        print_color 31 "        Brak urządzeń LAN do wyświetlenia schematu."
    fi
else
    print_color 31 "Brak interfejsów LAN do wyświetlenia."
fi

echo ""
}

main() {
print_color 32 "==============================================="
print_color 32 "  ENS - SKANER SIECI LOKALNEJ - Wojtech 2025   "
print_color 32 "==============================================="
echo ""

# 1. Podstawowe informacje o sieci
print_color 36 "=== INFORMACJE O SIECI ==="
echo ""
print_color 36 "Brama domyślna:"
local gw=$(default_gateway)
if [[ -n $gw ]]; then
    print_color 32 "  → $gw"
else
    print_color 31 "  → Brama domyślna nieznaleziona"
fi

echo ""
print_color 36 "Dostępne podsieci:"
local subs=$(network_subnets)
if [[ -n $subs ]]; then
    echo "$subs" | while read -r line; do
        print_color 32 "  → $line"
    done
else
    print_color 31 "  → Nie znaleziono podsieci"
fi

echo ""
print_color 36 "Sprawdzanie konfliktów adresów podsieci:"
local conflicts=$(network_subnets | awk '{print $2}' | sort | uniq -d)
if [[ -z $conflicts ]]; then
    print_color 32 "  → Brak konfliktów adresów podsieci"
else
    print_color 31 "  → WYKRYTO KONFLIKTY:"
    echo "$conflicts" | while read -r conflict; do
        print_color 31 "    • $conflict"
    done
fi

echo ""

# 2. Informacje o interfejsach sieciowych
print_color 36 "=== INTERFEJSY SIECIOWE ==="
echo ""

declare -a ordered_interfaces
if command -v nmcli &>/dev/null; then
    mapfile -t nmcli_interfaces < <(nmcli -t -f DEVICE con show --active 2>/dev/null | cut -d':' -f1 | grep -v '^$')
    mapfile -t all_network_interfaces < <(ls /sys/class/net | grep -v lo)
    
    for iface in "${nmcli_interfaces[@]}"; do
        if [[ -n $iface && -d /sys/class/net/$iface ]]; then
            ordered_interfaces+=("$iface")
        fi
    done
    
    for iface in "${all_network_interfaces[@]}"; do
        if [[ ! " ${ordered_interfaces[*]} " == *" $iface "* ]]; then
            ordered_interfaces+=("$iface")
        fi
    done
else
    mapfile -t ordered_interfaces < <(ls /sys/class/net | grep -v lo)
fi

for iface in "${ordered_interfaces[@]}"; do
    local type=$(interface_type "$iface")
    local ip=$(ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}' || echo "Brak IP")
    local state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    
    if [[ $type == "Wi-Fi" ]]; then
        local ssid=$(iw dev "$iface" link 2>/dev/null | awk '/SSID/ {print $2}')
        [[ -z $ssid ]] && ssid="Brak SSID"
        print_color 33 "  📶 $iface [$type] SSID: $ssid | IP: $ip | Status: $state"
    elif [[ $type == "LAN-Ethernet" ]]; then
        print_color 32 "  🔌 $iface [$type] IP: $ip | Status: $state"
    else
        print_color 31 "  ❓ $iface [Unknown] IP: $ip | Status: $state"
    fi
done

echo ""

# 3. Wyświetl wszystkie urządzenia
show_all_devices

# 4. Skanuj nierozpoznane urządzenia
scan_unknown_devices

# 5. Skanuj urządzenia IoT
scan_iot_devices

# 6. Rysuj schematy sieci (aktualizowane na bieżąco)
print_network_architecture

print_color 32 "==============================================="
print_color 32 "           SKANOWANIE ZAKOŃCZONE"
print_color 32 "==============================================="
}

# Uruchom główną funkcję
main