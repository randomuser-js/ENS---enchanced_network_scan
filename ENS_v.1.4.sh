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
}

default_gateway() {
ip route | awk '/default/ {print $3}'
}

network_subnets() {
ip -o -f inet addr show | awk '{print $2, $4}'
}

# Funkcja do parsowania wyników arp-scan i zwracania IP i MAC z identyfikacją urządzeń
parse_arp_scan_results() {
local interface=$1
# Poprawka: Usunięto 2>/dev/null, aby błędy arp-scan (np. brak uprawnień) były widoczne.
# To kluczowe dla diagnozy problemu z niewykrywaniem urządzeń LAN.
arp-scan --interface="$interface" --localnet | awk 'NR>2 && !/^Interface/ && !/^Starting/ && !/^Ending/ && !/packets/ && NF>=2 {print $1 ":" $2}'
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

# Smartfon MAC prefixes (przykładowe, do rozszerzenia)
local smartphone_prefixes=(
    "00:25:4B"  # Apple
    "00:1E:52"  # Apple
    "00:23:12"  # Samsung
    "00:1F:C6"  # Samsung
    "00:1A:11"  # Google
    "00:1D:A1"  # Google
    "00:21:00"  # Xiaomi
    "00:22:48"  # Huawei
    "00:24:D4"  # LG
    "00:26:B0"  # Sony
    "00:27:F8"  # HTC
    "00:28:E7"  # Motorola
    "00:2A:00"  # OnePlus
)

# Ogólne prefiksy dla kart sieciowych (laptopy, desktopy, serwery)
local generic_nic_prefixes=(
    "00:0C:29"  # VMware (często w wirtualnych maszynach/serwerach)
    "00:50:56"  # VMware
    "00:0C:29"  # Intel Corporation (często w laptopach/desktopach)
    "00:1C:C0"  # Intel Corporation
    "00:21:9B"  # Realtek Semiconductor Corp.
    "00:23:5A"  # Realtek Semiconductor Corp.
    "00:1B:21"  # Dell Inc.
    "00:1F:29"  # Dell Inc.
    "00:1E:C9"  # HP
    "00:21:70"  # HP
    "00:19:B9"  # ASUSTek Computer Inc.
    "00:22:15"  # ASUSTek Computer Inc.
    "00:1D:E0"  # Giga-Byte Technology Co.,Ltd.
    "00:23:8B"  # Giga-Byte Technology Co.,Ltd.
    "00:1A:A0"  # Cisco Systems, Inc.
    "00:1B:D4"  # Cisco Systems, Inc.
    "00:0A:95"  # Microsoft Corp. (często w wirtualnych maszynach Hyper-V)
    "00:15:5D"  # Microsoft Corp.
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

# Sprawdź Smartfon
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${smartphone_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="Smartfon"
            color_code="32" # zielony
            break
        fi
    done
fi

# Sprawdź ogólne karty sieciowe (Laptop/Desktop/Server)
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${generic_nic_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            # Można by tu dodać bardziej zaawansowaną logikę rozróżniania
            # np. na podstawie otwartych portów, ale to wykracza poza zakres MAC OUI.
            # Na razie przyjmujemy ogólny typ.
            device_type="Komputer/Serwer"
            color_code="37" # szary
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
local router_type="Router/AP"

# Próbujemy z arp -n i grep - bardzo prymitywne
local mac=$(arp -n | grep "$gw_ip" | awk '{print $3}')
if [[ -n $mac ]]; then
    # Vendor z OUI (jeśli masz zainstalowane narzędzie "oui")
    if command -v oui &>/dev/null; then
        vendor=$(oui "$mac" | head -1 | awk -F'\t' '{print $2}')
    fi
    
    # Sprawdź, czy brama to smartfon (hotspot)
    local device_info=$(identify_device_type "$mac" "$gw_ip")
    local device_type=$(echo "$device_info" | cut -d':' -f1)
    if [[ "$device_type" == "Smartfon" ]]; then
        router_type="Smartfon (Hotspot)"
    fi
fi
echo "$gw_ip" "$vendor" "$model" "$router_type"
}

# Funkcja do parsowania wyników arp-scan i zwracania IP i MAC z identyfikacją urządzeń
parse_arp_scan_results() {
local interface=$1
# Poprawka: Usunięto 2>/dev/null, aby błędy arp-scan (np. brak uprawnień) były widoczne.
# To kluczowe dla diagnozy problemu z niewykrywaniem urządzeń LAN.
arp-scan --interface="$interface" --localnet | awk 'NR>2 && !/^Interface/ && !/^Starting/ && !/^Ending/ && !/packets/ && NF>=2 {print $1 ":" $2}'
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
                        local hn_raw=$(get_hostname "$ip_addr")
                        local hn="${hn_raw:0:25}" # Poprawka ASCII: Skróć nazwę hosta
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
                        local hn_raw=$(get_hostname "$ip_addr")
                        local hn="${hn_raw:0:25}" # Poprawka ASCII: Skróć nazwę hosta
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
print_color 36 "Analiza topologii sieci (może wymagać 'traceroute' i uprawnień roota)..."
echo ""

local found_any=false
local has_traceroute=false
if command -v traceroute &>/dev/null; then
    has_traceroute=true
fi

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
                    local hn_raw=$(get_hostname "$ip_addr")
                    local hn="${hn_raw:0:25}" # Poprawka ASCII: Skróć nazwę hosta
                    local relationship=""

                    # Usprawnienie: Dodano analizę połączeń i routingu za pomocą traceroute
                    if [[ "$has_traceroute" == true && $EUID -eq 0 ]]; then
                        local trace_output
                        trace_output=$(traceroute -n -w 1 -q 1 "$ip_addr" 2>/dev/null | grep -v 'traceroute to')
                        local hops=$(echo "$trace_output" | wc -l)
                        if [[ $hops -gt 1 ]]; then
                            # Pierwszy hop to router pośredniczący
                            local via_router
                            via_router=$(echo "$trace_output" | awk 'NR==1 {print $2}')
                            if [[ "$via_router" != "*" ]]; then
                                relationship=" (przez router $via_router)"
                            fi
                        fi
                    fi
                    
                    print_color "$color_code" "  → $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)$relationship"
                    found_any=true
                fi
            fi
        done
        echo ""
    fi
done

if [[ "$has_traceroute" == false ]]; then
    print_color 33 "Ostrzeżenie: 'traceroute' nie jest zainstalowany. Analiza topologii sieci jest niedostępna."
    echo ""
elif [[ $EUID -ne 0 ]]; then
    print_color 33 "Ostrzeżenie: Uruchom skrypt jako root, aby użyć 'traceroute' do analizy topologii sieci."
    echo ""
fi

if [[ $found_any == false ]]; then
    print_color 31 "Brak urządzeń do wyświetlenia"
fi


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
local router_type="${router_info[3]}"
local ip_line="IP: $gw_ip"
local vendor_line="Vendor: $gw_vendor"

# Nowoczesna grafika ASCII routera z falami Wi-Fi
print_color 94 "                    ╔═══════════════════╗"
print_color 94 "                    ║  [INTERNET-WAN]   ║"
print_color 94 "                    ╚═════════╤═════════╝"
print_color 94 "                              │"
print_color 35 "                    ┌─────────┴─────────┐"
# Poprawka rysowania ASCII - przycinanie tekstu, aby pasował do ramki
print_color 35 "$(printf "                    │ %-18s│" "🌐 $router_type")"
print_color 35 "$(printf "                    │ %-18s│" "${ip_line:0:18}")"
print_color 35 "$(printf "                    │ %-18s│" "${vendor_line:0:18}")"
print_color 35 "                    └───────────────────┘"

if [[ ${#wifi_labels[@]} -gt 0 ]]; then
    print_color 33 "Wi-Fi: ${wifi_labels[0]}"
    echo ""
    
    # Dynamiczne generowanie grafiki fal Wi-Fi i urządzeń
    local wifi_devices_found=false
    local wifi_device_icons=()
    local wifi_device_names=()

    for wifi_iface in "${wifi_interfaces[@]}"; do
        state=$(cat /sys/class/net/"$wifi_iface"/operstate 2>/dev/null || echo "unknown")
        if [[ $state == "up" ]]; then
            mapfile -t current_wifi_devices < <(parse_arp_scan_results "$wifi_iface")
            for device in "${current_wifi_devices[@]}"; do
                if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                    local ip_addr=$(echo "$device" | cut -d':' -f1)
                    local mac_addr=$(echo "$device" | cut -d':' -f2-)
                    if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                        local hn_raw=$(get_hostname "$ip_addr")
                        local hn="${hn_raw:0:10}" # Shorten hostname for display
                        local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                        local device_type=$(echo "$device_info" | cut -d':' -f1)
                        
                        local device_icon="❓" # Default unknown
                        case $device_type in
                            "Raspberry Pi") device_icon="🔴" ;;
                            "Arduino/ESP") device_icon="🔵" ;;
                            "ODROID") device_icon="🟣" ;;
                            "Banana Pi") device_icon="🟡" ;;
                            "ODYSSEY x86") device_icon="🔷" ;;
                            "Smartfon") device_icon="📱" ;;
                            "Komputer/Serwer") device_icon="💻" ;;
                            *) device_icon="❓" ;;
                        esac
                        
                        wifi_device_icons+=("$device_icon")
                        wifi_device_names+=("[$hn]")
                        wifi_devices_found=true
                    fi
                fi
            done
        fi
    done

    if [[ "$wifi_devices_found" == true ]]; then
        print_color 33 "                 ))) Wi-Fi Waves ((("
        print_color 33 "              ))))               (((("
        print_color 33 "           ))))                     (((("
        print_color 33 "        ))))          📡              (((("
        print_color 33 "     ))))                                (((("
        print_color 33 "  ))))      "

        local current_line_icons=""
        local current_line_names=""
        local devices_on_current_line=0
        local max_devices_per_line=5 # Adjust as needed for aesthetics

        for i in "${!wifi_device_icons[@]}"; do
            current_line_icons+="${wifi_device_icons[$i]}      "
            current_line_names+="${wifi_device_names[$i]}  "
            ((devices_on_current_line++))

            if (( devices_on_current_line >= max_devices_per_line )); then
                print_color 33 "$current_line_icons"
                print_color 33 "$current_line_names"
                current_line_icons="  ))))      "
                current_line_names=" "
                devices_on_current_line=0
            fi
        done

        # Print any remaining devices
        if [[ -n "$current_line_icons" ]]; then
            print_color 33 "$current_line_icons"
            print_color 33 "$current_line_names"
        fi
        print_color 33 "                                 ((((" # Closing wave
        echo ""
        print_color 32 "📊 Znaleziono łącznie ${#wifi_device_icons[@]} urządzeń Wi-Fi"
    else
        print_color 31 "                 ))) No Wi-Fi ((("
        print_color 31 "              ))))           (((("
        print_color 31 "           ))))                 (((("
        print_color 31 "        ))))      ❌ Wi-Fi       (((("
        print_color 31 "     ))))       DISABLED          (((("
        print_color 31 "  ))))                              (((("
        print_color 31 " [Brak aktywnych urządzeń Wi-Fi]"
    fi
else
    # Grafika dla braku Wi-Fi (if no wifi interfaces at all)
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

# Definiowanie adresu IP serwera Proxmox/Proxy (do dostosowania przez użytkownika)
# Jeśli nie używasz Proxmox/Proxy, ustaw na pusty string: PROXMOX_IP=""
PROXMOX_IP="192.168.1.10" # PRZYKŁAD: Zmień na rzeczywisty IP serwera Proxmox/Proxy

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

    # Dodanie serwera Proxmox/Proxy do schematu LAN
    if [[ -n "$PROXMOX_IP" ]]; then
        local proxmox_hn=$(get_hostname "$PROXMOX_IP")
        print_color 35 "          ┌──────────┼──────────┐"
        print_color 35 "          │          │          │"
        print_color 35 "          │ 🌐 PROXMOX/PROXY │"
        print_color 35 "          │ IP: $PROXMOX_IP │"
        print_color 35 "          │ Host: $proxmox_hn │"
        print_color 35 "          └──────────┼──────────┘"
        print_color 35 "                     ║"
    else
        print_color 35 "          ┌──────────┼──────────┐"
        print_color 35 "          │          │          │"
    fi

    # Skanowanie urządzeń LAN w czasie rzeczywistym
    local lan_found=false
    local lan_device_count=0
    for lan_iface in "${lan_interfaces[@]}"; do
        if [[ -n $lan_iface ]]; then
            state=$(cat /sys/class/net/"$lan_iface"/operstate 2>/dev/null || echo "unknown")
            if [[ $state == "up" ]]; then
                mapfile -t lan_devices < <(parse_arp_scan_results "$lan_iface")
                for device in "${lan_devices[@]}"; do
                    if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                        local ip_addr=$(echo "$device" | cut -d':' -f1)
                        local mac_addr=$(echo "$device" | cut -d':' -f2-)
                        if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                            # Pomiń ten komputer (host) w liście urządzeń
                            if [[ $ip_addr != $this_ip ]]; then
                                local hn_raw=$(get_hostname "$ip_addr")
                                local hn="${hn_raw:0:25}" # Poprawka ASCII: Skróć nazwę hosta
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
                                    "Smartfon") device_icon="📱" ;;
                                    "Komputer/Serwer") device_icon="💻" ;;
                                    *) device_icon="❓" ;;
                                esac
                                    
                                print_color "$color_code" "    $device_icon $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                            fi
                        fi
                    fi
                done
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
# Poprawka: Sprawdzenie uprawnień roota na początku.
if [[ $EUID -ne 0 ]]; then
    print_color 31 "Ostrzeżenie: Skrypt wymaga uprawnień roota (sudo) do pełnej funkcjonalności."
    print_color 31 "Bez sudo, skanowanie ARP i analiza topologii mogą nie działać poprawnie."
    echo
fi

print_color 32 "==============================================="
print_color 32 "  ENS - SKANER SIECI LAN - IoT - Wojtech 2025   "
print_color 32 "==============================================="
echo ""

# Identyfikacja lokalnego hosta
print_color 36 "=== INFORMACJE O LOKALNYM HOŚCIE ==="
local local_ip=$(hostname -I | awk '{print $1}')
local local_mac=$(ip link show $(ip route | awk '/default/ {print $5}') | awk '/ether/ {print $2}')
local local_device_info=$(identify_device_type "$local_mac" "$local_ip")
local local_device_type=$(echo "$local_device_info" | cut -d':' -f1)
local local_color_code=$(echo "$local_device_info" | cut -d':' -f2)
print_color "$local_color_code" "  Ten host jest: $local_device_type (IP: $local_ip ; MAC: $local_mac)"
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