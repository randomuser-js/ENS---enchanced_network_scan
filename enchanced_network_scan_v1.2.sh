#!/bin/bash
# skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
# każdego hosta oraz wykryć nieznane hosty
# Mój 1 skrypt napisany przez ChatGPT- vibe coding i claude.AI - Wojtech
# Skrypt skanuje dostepne sieci podaje jej parametry IP, Brama, adres MAC urzadzenia, na koniec rysuje prosta grafikę w ASCII.

# do poprawy!

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
print_color 36 "Wyszukiwanie urządzeń w sieci bez przypisanego adresu IP (incomplete ARP)..."
local incomplete_devices=$(ip neigh | awk '/INCOMPLETE/ {print $1}')
if [[ -n $incomplete_devices ]]; then
while read -r ip; do
local mac=$(ip neigh | grep "$ip" | awk '{print $5}')
if [[ -n $mac && $mac != "00:00:00:00:00:00" ]]; then
local hn=$(get_hostname "$ip")
print_color 31 "Nierozpoznane urządzenie: $hn (IP: $ip ; MAC: $mac)"
fi
done <<< "$incomplete_devices"
else
print_color 32 "Brak nierozpoznanych urządzeń w sieci."
fi
}

# Funkcja do identyfikacji typu urządzenia IoT na podstawie MAC
identify_iot_device() {
local mac=$1
local mac_prefix=$(echo "$mac" | cut -d':' -f1-3 | tr '[:lower:]' '[:upper:]')
local mac_prefix_2=$(echo "$mac" | cut -d':' -f1-2 | tr '[:lower:]' '[:upper:]')

# Raspberry Pi MAC prefiksy
case $mac_prefix in
    "28:CD:C1"|"2C:CF:67"|"B8:27:EB"|"D8:3A:DD"|"DC:A6:32"|"E4:5F:01")
        echo "RaspberryPi"
        return 0
        ;;
esac

# Arduino MAC prefiksy
case $mac_prefix in
    "A8:61:0A")
        echo "Arduino"
        return 0
        ;;
esac

# ESP32/ESP8266 (często używane w projektach Arduino/IoT)
case $mac_prefix in
    "18:FE:34"|"1A:FE:34"|"5C:CF:7F"|"24:6F:28"|"30:AE:A4"|"84:CC:A8"|"A4:CF:12"|"C8:C9:A3"|"CC:50:E3"|"DC:4F:22"|"E8:DB:84"|"EC:FA:BC"|"F0:08:D1"|"F4:CF:A2")
        echo "ESP32/ESP8266"
        return 0
        ;;
esac

# Inne popularne IoT prefiksy
case $mac_prefix in
    "00:17:88"|"00:1E:C0"|"00:04:A3"|"00:50:C2"|"70:B3:D5"|"D4:3D:7E"|"F0:7D:68")
        echo "IoT"
        return 0
        ;;
esac

return 1
}

scan_iot_devices() {
print_color 36 "Wyszukiwanie IoT - Raspberry Pi, Arduino, ESP32/ESP8266..."
local iot_found=false
local interfaces
mapfile -t interfaces < <(ls /sys/class/net | grep -v lo)

for iface in "${interfaces[@]}"; do
    if [[ -d /sys/class/net/$iface ]]; then
        local devices=$(parse_arp_scan_results "$iface")
        if [[ -n $devices ]]; then
            while IFS=':' read -r ip mac_with_spaces; do
                local mac=$(echo "$mac_with_spaces" | xargs)
                if [[ -n $ip && -n $mac && $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_type=$(identify_iot_device "$mac")
                    if [[ $? -eq 0 ]]; then
                        iot_found=true
                        local hn=$(get_hostname "$ip")
                        case $device_type in
                            "RaspberryPi")
                                print_color 35 "🍓 Raspberry Pi: $hn (IP: $ip ; MAC: $mac)"
                                ;;
                            "Arduino")
                                print_color 34 "🔧 Arduino: $hn (IP: $ip ; MAC: $mac)"
                                ;;
                            "ESP32/ESP8266")
                                print_color 34 "📡 ESP32/ESP8266: $hn (IP: $ip ; MAC: $mac)"
                                ;;
                            "IoT")
                                print_color 90 "🌐 Urządzenie IoT: $hn (IP: $ip ; MAC: $mac)"
                                ;;
                        esac
                    fi
                fi
            done <<< "$devices"
        fi
    fi
done

if [[ $iot_found == false ]]; then
    print_color 32 "Brak urządzeń IoT w sieci."
fi
echo ""
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

# Autouzupełnianie interfejsów do read
_autocomplete_interfaces() {
local cur="${COMP_WORDS[COMP_CWORD]}"
COMPREPLY=( $(compgen -W "$(ls /sys/class/net | grep -v lo)" -- "$cur") )
}

# Funkcja do parsowania wyników arp-scan i zwracania IP i MAC
parse_arp_scan_results() {
local interface=$1
arp-scan --interface="$interface" --localnet 2>/dev/null | awk 'NR>2 && !/^Interface/ && !/^Starting/ && !/^Ending/ && !/packets/ && NF>=2 {print $1 ":" $2}'
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
ssid=$(iw dev "$iface" link | awk '/SSID/ {print $2}')
[[ -z $ssid ]] && ssid="Brak SSID"
label="$iface [$type] SSID: $ssid IP: $ip Status: $state"
wifi_labels[i]="$label"
wifi_interfaces[i]="$iface"
((i++))
elif [[ $type == "LAN-Ethernet" ]]; then
label="$iface [$type] IP: $ip Status: $state"
lan_labels[${#lan_labels[@]}]="$label"
lan_interfaces[${#lan_interfaces[@]}]="$iface"
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
printf "%${padding}s\n" " |"
print_color 35 "$(printf "%${padding}s\n" "[Router]")"
print_color 35 "$(printf "%${padding}s\n" "IP: $gw_ip")"
print_color 35 "$(printf "%${padding}s\n" "Producent: $gw_vendor")"
print_color 35 "$(printf "%${padding}s\n" "Model: $gw_model")"

if [[ ${#wifi_labels[@]} -gt 0 ]]; then
print_color 33 "|--> ${wifi_labels[0]}"
printf "%${padding}s\n" " /|\\"
printf "%${padding}s\n" " / | \\"

# Skanowanie urządzeń Wi-Fi z wybranym interfejsem Wi-Fi
local wifi_found=false
for wifi_iface in "${wifi_interfaces[@]}"; do
if [[ -n $wifi_iface ]]; then
mapfile -t wifi_devices < <(parse_arp_scan_results "$wifi_iface")
if [[ ${#wifi_devices[@]} -gt 0 ]]; then
wifi_found=true
for device in "${wifi_devices[@]}"; do
if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
local ip_addr=$(echo "$device" | cut -d':' -f1)
local mac_addr=$(echo "$device" | cut -d':' -f2-)
local hn=$(get_hostname "$ip_addr")
if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    local device_type=$(identify_iot_device "$mac_addr")
    if [[ $? -eq 0 ]]; then
        case $device_type in
            "RaspberryPi")
                print_color 35 " 🍓 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "Arduino")
                print_color 34 " 🔧 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "ESP32/ESP8266")
                print_color 34 " 📡 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "IoT")
                print_color 90 " 🌐 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
        esac
    else
        print_color 33 " $hn (IP: $ip_addr ; MAC: $mac_addr)"
    fi
fi
fi
done
fi
fi
done

if [[ $wifi_found == false ]]; then
print_color 33 " (Brak urządzeń Wi-Fi do wyświetlenia)"
fi
else
echo "|-->"
printf "%${padding}s\n" " /|\\"
printf "%${padding}s\n" " / | \\"
print_color 33 " (Brak urządzeń Wi-Fi do wyświetlenia)"
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
# Pobierz informacje o tym komputerze
local this_hostname=$(hostname)
local this_ip=$(ip -o -4 addr show "${lan_interfaces[0]}" | awk '{print $4}' | cut -d'/' -f1)
local this_mac=$(ip link show "${lan_interfaces[0]}" | awk '/ether/ {print $2}')
print_color 32 "Ten Komputer $this_hostname (IP: $this_ip ; MAC: $this_mac)"
print_color 32 " |"
print_color 35 " +---[LAN]---> Switch (Producent: Unknown, Model: Unknown)"
print_color 32 " |"

# Skanowanie urządzeń LAN z wybranym interfejsem LAN
local lan_found=false
for lan_iface in "${lan_interfaces[@]}"; do
if [[ -n $lan_iface ]]; then
mapfile -t lan_devices < <(parse_arp_scan_results "$lan_iface")
if [[ ${#lan_devices[@]} -gt 0 ]]; then
lan_found=true
for device in "${lan_devices[@]}"; do
if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
local ip_addr=$(echo "$device" | cut -d':' -f1)
local mac_addr=$(echo "$device" | cut -d':' -f2-)
local hn=$(get_hostname "$ip_addr")
if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    local device_type=$(identify_iot_device "$mac_addr")
    if [[ $? -eq 0 ]]; then
        case $device_type in
            "RaspberryPi")
                print_color 35 " +---[LAN]---> 🍓 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "Arduino")
                print_color 34 " +---[LAN]---> 🔧 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "ESP32/ESP8266")
                print_color 34 " +---[LAN]---> 📡 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
            "IoT")
                print_color 90 " +---[LAN]---> 🌐 $hn (IP: $ip_addr ; MAC: $mac_addr)"
                ;;
        esac
    else
        print_color 32 " +---[LAN]---> $hn (IP: $ip_addr ; MAC: $mac_addr)"
    fi
fi
fi
done
fi
fi
done

if [[ $lan_found == false ]]; then
print_color 31 "Brak urządzeń LAN do wyświetlenia schematu."
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
print_color 36 "Informacje o dostępnych interfejsach sieciowych (uporządkowane wg priorytetu):"
# Pobierz interfejsy z nmcli uporządkowane według priorytetu
declare -a ordered_interfaces
if command -v nmcli &>/dev/null; then
# Użyj nmcli do pobrania interfejsów w kolejności priorytetu
mapfile -t nmcli_interfaces < <(nmcli -t -f DEVICE con show --active | cut -d':' -f1 | grep -v '^$')
# Dodaj także nieaktywne interfejsy
mapfile -t all_network_interfaces < <(ls /sys/class/net | grep -v lo)
# Najpierw aktywne z nmcli
for iface in "${nmcli_interfaces[@]}"; do
if [[ -n $iface && -d /sys/class/net/$iface ]]; then
ordered_interfaces+=("$iface")
fi
done
# Potem pozostałe nieaktywne
for iface in "${all_network_interfaces[@]}"; do
if [[ ! " ${ordered_interfaces[*]} " == *" $iface "* ]]; then
ordered_interfaces+=("$iface")
fi
done
else
# Fallback - jeśli nmcli nie jest dostępne
mapfile -t ordered_interfaces < <(ls /sys/class/net | grep -v lo)
fi
# Wyświetl interfejsy w kolejności priorytetu
for iface in "${ordered_interfaces[@]}"; do
type=$(interface_type "$iface")
ip=$(ip -o -4 addr show "$iface" | awk '{print $4}')
state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
# Sprawdź czy interfejs jest aktywny w nmcli
local priority_info=""
if command -v nmcli &>/dev/null; then
local connection_name=$(nmcli -t -f DEVICE,NAME con show --active | grep "^$iface:" | cut -d':' -f2)
if [[ -n $connection_name ]]; then
priority_info=" [Aktywne: $connection_name]"
else
priority_info=" [Nieaktywne]"
fi
fi

case $type in
"Wi-Fi") print_color 33 "$iface [$type] IP: $ip Status: $state$priority_info" ;;
"LAN-Ethernet") print_color 32 "$iface [$type] IP: $ip Status: $state$priority_info" ;;
*) print_color 31 "$iface [Unknown] IP: $ip Status: $state$priority_info" ;;
esac
done
# Użyj uporządkowanych interfejsów dla reszty skryptu
interfaces=("${ordered_interfaces[@]}")

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
scan_incomplete_arp

echo ""
scan_iot_devices

print_network_architecture

echo ""
print_color 32 "Skanowanie zakończone."
}

main