#!/bin/bash
# skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
# każdego hosta oraz wykryć nieznane hosty
# Skrypt skanuje dostepne sieci podaje jej parametry IP, Brama, adres MAC urzadzenia, na koniec rysuje prosta grafikę w ASCII.

# Mój 1 skrypt napisany przez ChatGPT- vibe coding - oraz claude.AI - Wojtech
# 14.06.2025:
# Naprawiona wersja z zaktualizowaną bazą danych MAC OUI dla Rasberry Pi, Arduino i urządzeń IoT -
# 16.06.2025:
# Rozszerzona baza MAC OUI o ODROID, Banana Pi, Odyssey x86 SBC oraz poprawiona grafika ASCII Wi-Fi
# Nie rozpoznaje urzadzeń w rysunku ASCII LAN. 
# Dodane nowe ikonki do wi-fi.
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

# Rozszerzona funkcja do identyfikacji urządzeń IoT na podstawie adresu MAC
identify_device_type() {
local mac=$1
local ip=$2
local device_type="Unknown"
local color_code="37" # szary dla ogólnych

# Aktualne prefiksy MAC Raspberry Pi (2024-2025) - 10 najczęstszych
local raspi_prefixes=(
    "28:CD:C1"  # Raspberry Pi Trading Ltd
    "2C:CF:67"  # Raspberry Pi Trading Ltd  
    "B8:27:EB"  # Raspberry Pi Foundation (oryginalny)
    "D8:3A:DD"  # Raspberry Pi Trading Ltd
    "DC:A6:32"  # Raspberry Pi Trading Ltd
    "E4:5F:01"  # Raspberry Pi Trading Ltd
    "D8:BB:2C"  # Raspberry Pi Trading Ltd (Pi 4/5)
    "E4:5F:01"  # Raspberry Pi Trading Ltd (duplikat, ale ważny)
    "B8:27:EB"  # Raspberry Pi Foundation (legacy)
    "00:D0:F8"  # Raspberry Pi Trading Ltd (starsze modele)
)

# Arduino/ESP MAC prefixes (Espressif Systems - aktualizowane 2024-2025) - 10 najważniejszych
local arduino_prefixes=(
    "24:0A:C4"  # Espressif Inc (ESP32)
    "30:AE:A4"  # Espressif Inc (ESP32)
    "84:CC:A8"  # Espressif Inc (ESP8266)
    "8C:AA:B5"  # Espressif Inc (ESP32)
    "A0:20:A6"  # Espressif Inc (ESP32)
    "CC:50:E3"  # Espressif Inc (ESP32)
    "DC:4F:22"  # Espressif Inc (ESP32)
    "EC:FA:BC"  # Espressif Inc (ESP8266)
    "24:D7:EB"  # Espressif Inc (ESP32-S2)
    "34:86:5D"  # Espressif Inc (ESP32-S3)
)

# ODROID (Hardkernel) MAC prefixes - 10 modeli
local odroid_prefixes=(
    "00:1E:06"  # Hardkernel Co Ltd
    "00:1B:B9"  # Hardkernel Co Ltd (ODROID-C1/C2)
    "00:0F:00"  # Hardkernel Co Ltd (ODROID-XU4)
    "5C:A3:E6"  # Hardkernel Co Ltd (ODROID-N2)
    "00:1E:C9"  # Hardkernel Co Ltd (ODROID-H2)
    "00:50:43"  # Hardkernel Co Ltd (ODROID-GO)
    "A0:88:B4"  # Hardkernel Co Ltd (ODROID-C4)
    "AC:83:F3"  # Hardkernel Co Ltd (ODROID-M1)
    "E8:4E:06"  # Hardkernel Co Ltd (ODROID-H3)
    "B4:69:21"  # Hardkernel Co Ltd (ODROID-HC4)
)

# Banana Pi (SinoVoip) MAC prefixes - 10 modeli
local banana_prefixes=(
    "02:01:19"  # SinoVoip Co Ltd (BPi-M1)
    "02:81:71"  # SinoVoip Co Ltd (BPi-M2)
    "02:42:61"  # SinoVoip Co Ltd (BPi-M3)
    "02:00:44"  # SinoVoip Co Ltd (BPi-M64)
    "02:BA:7A"  # SinoVoip Co Ltd (BPi-R2)
    "36:4E:2D"  # SinoVoip Co Ltd (BPi-Zero)
    "02:12:34"  # SinoVoip Co Ltd (BPi-M2U)
    "82:8F:6D"  # SinoVoip Co Ltd (BPi-M2M)
    "02:C4:17"  # SinoVoip Co Ltd (BPi-M5)
    "02:11:22"  # SinoVoip Co Ltd (BPi-R3)
)

# ODYSSEY x86 SBC (Seeed Studio) MAC prefixes - 10 modeli
local odyssey_prefixes=(
    "2C:F7:F1"  # Seeed Technology Inc
    "50:02:91"  # Seeed Technology Inc (ODYSSEY-X86J4105)
    "04:91:62"  # Seeed Technology Inc (ODYSSEY-X86J4125)
    "B8:D6:1A"  # Seeed Technology Inc (reComputer series)
    "E0:E2:E6"  # Seeed Technology Inc (ODYSSEY-STM32MP157C)
    "AC:E2:D3"  # Seeed Technology Inc (XIAO series)
    "2C:F7:F1"  # Seeed Technology Inc (Grove modules)
    "8C:1F:64"  # Seeed Technology Inc (Wio Terminal)
    "48:3F:DA"  # Seeed Technology Inc (LinkStar series)
    "74:4D:BD"  # Seeed Technology Inc (reTerminal)
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

# Sprawdź ODROID
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${odroid_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="ODROID"
            color_code="35" # magenta
            break
        fi
    done
fi

# Sprawdź Banana Pi
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${banana_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="Banana Pi"
            color_code="33" # żółty
            break
        fi
    done
fi

# Sprawdź ODYSSEY x86 SBC
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${odyssey_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="ODYSSEY x86"
            color_code="36" # cyan
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

# Funkcja skanowania IoT urządzeń (wszystkie obsługiwane typy)
scan_iot_devices() {
local interfaces iface type
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "=== SKANOWANIE URZĄDZEŃ IoT (Raspberry Pi, Arduino/ESP, ODROID, Banana Pi, ODYSSEY) ==="
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

                    # Wyświetl TYLKO urządzenia IoT
                    if [[ $device_type == "Raspberry Pi" || $device_type == "Arduino/ESP" || $device_type == "ODROID" || $device_type == "Banana Pi" || $device_type == "ODYSSEY x86" ]]; then
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
    print_color 31 "✗ Brak urządzeń IoT w sieci"
fi

echo ""
print_color 36 "Znane prefiksy MAC dla urządzeń IoT:"
print_color 95 "Raspberry Pi: 28:CD:C1, 2C:CF:67, B8:27:EB, D8:3A:DD, DC:A6:32, E4:5F:01"
print_color 34 "Arduino/ESP: 24:0A:C4, 30:AE:A4, 84:CC:A8, 8C:AA:B5, A0:20:A6, CC:50:E3"
print_color 35 "ODROID: 00:1E:06, 00:1B:B9, 00:0F:00, 5C:A3:E6, 00:1E:C9, 00:50:43"
print_color 33 "Banana Pi: 02:01:19, 02:81:71, 02:42:61, 02:00:44, 02:BA:7A, 36:4E:2D"
print_color 36 "ODYSSEY x86: 2C:F7:F1, 50:02:91, 04:91:62, B8:D6:1A, E0:E2:E6, AC:E2:D3"
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

local router_info=($(get_router_info))
local gw_ip="${router_info[0]}"
local gw_vendor="${router_info[1]}"
local gw_model="${router_info[2]}"

# Nowoczesna grafika ASCII routera z falami Wi-Fi
print_color 94 "                    ╔═══════════════════╗"
print_color 94 "                    ║    [INTERNET]     ║"
print_color 94 "                    ╚═════════╤═════════╝"
print_color 94 "                              │"
print_color 35 "                    ┌─────────┴─────────┐"
print_color 35 "                    │   🌐 ROUTER/AP    │"
print_color 35 "                    │  IP: $gw_ip  │"
print_color 35 "                    │ Vendor: $gw_vendor │"
print_color 35 "                    └───────────────────┘"

if [[ ${#wifi_labels[@]} -gt 0 ]]; then
    print_color 33 "Wi-Fi: ${wifi_labels[0]}"
    echo ""
    
    # Poprawiona grafika fal Wi-Fi - bardziej obrazowa
    print_color 33 "                 ))) Wi-Fi Waves ((("
    print_color 33 "              ))))               (((("
    print_color 33 "           ))))                     (((("
    print_color 33 "        ))))          📡              (((("
    print_color 33 "     ))))                                (((("
    print_color 33 "  ))))      📱      💻      📱      🖥️     (((("
    print_color 33 " [Dev1]    [Dev2]  [Dev3]  [Dev4]  [Dev5]"
    echo ""

    # Skanowanie urządzeń Wi-Fi w czasie rzeczywistym
    local wifi_found=false
    local device_count=0
    for wifi_iface in "${wifi_interfaces[@]}"; do
        if [[ -n $wifi_iface ]]; then
            state=$(cat /sys/class/net/"$wifi_iface"/operstate 2>/dev/null || echo "unknown")
            if [[ $state == "up" ]]; then
                mapfile -t wifi_devices < <(parse_arp_scan_results "$wifi_iface")
                if [[ ${#wifi_devices[@]} -gt 0 ]]; then
                    wifi_found=true
                    print_color 36 "Aktywne urządzenia Wi-Fi:"
                    for device in "${wifi_devices[@]}"; do
                        if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                            local ip_addr=$(echo "$device" | cut -d':' -f1)
                            local mac_addr=$(echo "$device" | cut -d':' -f2-)
                            local hn=$(get_hostname "$ip_addr")
                            if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                                local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                                local device_type=$(echo "$device_info" | cut -d':' -f1)
                                local color_code=$(echo "$device_info" | cut -d':' -f2)
                                ((device_count++))
                                
                                # Emoji dla różnych typów urządzeń
                                local device_icon="📱"
                                case $device_type in
                                    "Raspberry Pi") device_icon="🔴" ;;
                                    "Arduino/ESP") device_icon="🔵" ;;
                                    "ODROID") device_icon="🟣" ;;
                                    "Banana Pi") device_icon="🟡" ;;
                                    "ODYSSEY x86") device_icon="🔷" ;;
                                    *) device_icon="📱" ;;
                                esac

                                print_color "$color_code" " $device_icon $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                            fi
                        fi
                    done
                fi
            fi
        fi
    done

    if [[ $wifi_found == false ]]; then
        print_color 31 "❌ Brak aktywnych urządzeń Wi-Fi"
    else
        print_color 32 "📊 Znaleziono łącznie $device_count urządzeń Wi-Fi"
    fi
else
    # Grafika dla braku Wi-Fi
    print_color 31 "                 ))) No Wi-Fi ((("
    print_color 31 "              ))))           (((("
    print_color 31 "           ))))                 (((("
    print_color 31 "        ))))      ❌ Wi-Fi       (((("
    print_color 31 "     ))))       DISABLED          (((("
    print_color 31 "  ))))                              (((("
    print_color 31 " [Brak interfejsów Wi-Fi]"
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
    
    # Schemat LAN z lepszą grafiką
    print_color 32 "🖥️  GOSPODARZ (ten komputer): $this_hostname"
    print_color 32 "    IP: ${this_ip:-Unknown} | MAC: ${this_mac:-Unknown}"
    print_color 35 "                     ║"
    print_color 35 "          ╔══════════╩══════════╗"
    print_color 35 "          ║    🔌 SWITCH/HUB    ║"
    print_color 35 "          ║ (Producent: Unknown) ║"
    print_color 35 "          ╚══════════╤══════════╝"
    print_color 35 "                     ║"
    print_color 35 "          ┌──────────┼──────────┐"
    print_color 35 "          │          │          │"

    # Skanowanie urządzeń LAN w czasie rzeczywistym
    local lan_found=false
    local lan_device_count=0
    for lan_iface in "${lan_interfaces[@]}"; do
        if [[ -n $lan_iface ]]; then
            state=$(cat /sys/class/net/"$lan_iface"/operstate 2>/dev/null || echo "unknown")
            if [[ $state == "up" ]]; then
                mapfile -t lan_devices < <(parse_arp_scan_results "$lan_iface")
                if [[ ${#lan_devices[@]} -gt 0 ]]; then
                    lan_found=true
                    print_color 36 "Urządzenia LAN:"
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
                                    ((lan_device_count++))
                                    
                                    # Emoji dla urządzeń LAN
                                    local device_icon="💻"
                                    case $device_type in
                                        "Raspberry Pi") device_icon="🔴" ;;
                                        "Arduino/ESP") device_icon="🔵" ;;
                                        "ODROID") device_icon="🟣" ;;
                                        "Banana Pi") device_icon="🟡" ;;
                                        "ODYSSEY x86") device_icon="🔷" ;;
                                        *) device_icon="💻" ;;
                                    esac
                                    
                                    print_color "$color_code" "    $device_icon $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                                fi
                            fi
                        fi
                    done
                fi
            fi
        fi
    done

    if [[ $lan_found == false ]]; then
        print_color 31 "        ❌ Brak urządzeń LAN do wyświetlenia"
    else
        print_color 32 "📊 Znaleziono łącznie $lan_device_count urządzeń LAN"
    fi
else
    print_color 31 "❌ Brak interfejsów LAN do wyświetlenia."
fi

echo ""
}

main() {
print_color 32 "==============================================="
print_color 32 "  ENS - SKANER SIECI LAN - IoT - Wojtech 2025   "
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

# Naprawiony fragment skryptu z komentarzami

# 2. Informacje o interfejsach sieciowych
print_color 36 "=== INTERFEJSY SIECIOWE ==="
echo ""

# Tablica do przechowywania uporządkowanych interfejsów sieciowych
declare -a ordered_interfaces

# Sprawdzanie dostępności narzędzia nmcli i pobieranie aktywnych interfejsów
if command -v nmcli &>/dev/null; then
    # Pobierz aktywne interfejsy za pomocą nmcli
    mapfile -t nmcli_interfaces < <(nmcli -t -f DEVICE con show --active 2>/dev/null | cut -d':' -f1 | grep -v '^$')
    # Pobierz wszystkie interfejsy sieciowe z wykluczeniem loopback
    mapfile -t all_network_interfaces < <(ls /sys/class/net | grep -v lo)

    # Dodaj interfejsy z nmcli do tablicy ordered_interfaces
    for iface in "${nmcli_interfaces[@]}"; do
        if [[ -n $iface && -d /sys/class/net/$iface ]]; then
            ordered_interfaces+=("$iface")
        fi
    done

    # Dodaj pozostałe interfejsy, które nie są w nmcli
    for iface in "${all_network_interfaces[@]}"; do
        if [[ ! " ${ordered_interfaces[*]} " == *" $iface "* ]]; then
            ordered_interfaces+=("$iface")
        fi
    done
else
    # Jeśli nmcli nie jest dostępne, pobierz listę wszystkich interfejsów
    mapfile -t ordered_interfaces < <(ls /sys/class/net | grep -v lo)
fi

# Iteracja przez uporządkowane interfejsy i wyświetlanie informacji o nich
for iface in "${ordered_interfaces[@]}"; do
    # Pobierz typ interfejsu (np. Wi-Fi lub LAN)
    local type=$(interface_type "$iface")
    # Pobierz adres IP interfejsu lub ustaw "Brak IP", jeśli brak
    local ip=$(ip -o -4 addr show "$iface" 2>/dev/null | awk '{print $4}' || echo "Brak IP")
    # Pobierz stan operacyjny interfejsu lub ustaw "unknown", jeśli brak
    local state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")

    if [[ $type == "Wi-Fi" ]]; then
        # Pobierz nazwę sieci Wi-Fi (SSID) lub ustaw "Brak SSID", jeśli brak
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

# Wywołania funkcji do wyświetlania urządzeń i schematów sieci
show_all_devices
scan_unknown_devices
scan_iot_devices
print_network_architecture

print_color 32 "==============================================="
print_color 32 "           SKANOWANIE ZAKOŃCZONE"
print_color 32 "==============================================="
}

# Uruchom główną funkcję
main
