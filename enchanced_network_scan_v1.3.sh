#!/bin/bash
# skrypt stworzony przy użyciu chataGPT przez Wojtecha - skanuje sieć lokalną by poznać parametry 
# każdego hosta oraz wykryć nieznane hosty
# Skrypt skanuje dostepne sieci podaje jej parametry IP, Brama, adres MAC urzadzenia, na koniec rysuje prosta grafikę w ASCII.

# Mój 1 skrypt napisany przez ChatGPT- vibe coding - oraz claude.AI - Wojtech
# 14.06.2025:
# Naprawiona wersja z zaktualizowaną bazą danych MAC OUI dla Rasberry Pi, Arduino i urządzeń IoT -

# Naprawić nie działa rozpoznawanie urządzeń po MAC - przypisuje Laptopwoi parametry z maliny!

# Do poprawy! błędy

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
local color_code="37" # szary dla ogólnych IoT

# Aktualne prefiksy MAC Raspberry Pi (2024-2025)
local raspi_prefixes=(
    "28:CD:C1"  # Raspberry Pi Trading Ltd
    "2C:CF:67"  # Raspberry Pi Trading Ltd  
    "B8:27:EB"  # Raspberry Pi Foundation (oryginalny)
    "D8:3A:DD"  # Raspberry Pi Trading Ltd
    "DC:A6:32"  # Raspberry Pi Trading Ltd
    "E4:5F:01"  # Raspberry Pi Trading Ltd
    "E4:5F:01"  # Nowy prefiks 2024
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

# Prefiksy typowych producentów laptopów/komputerów (do wykluczenia z IoT)
local laptop_prefixes=(
    "00:50:56"  # VMware
    "08:00:27"  # VirtualBox
    "52:54:00"  # QEMU/KVM
    "02:00:4C"  # Docker
    "00:15:5D"  # Microsoft Hyper-V
    "00:1C:42"  # Parallels
    "00:50:56"  # VMware ESX
    "AC:DE:48"  # Intel Corporation
    "00:1B:21"  # Intel Corporation
    "A4:BB:6D"  # Intel Corporation
    "3C:97:0E"  # Intel Corporation
    "7C:5C:F8"  # Intel Corporation
    "10:7B:44"  # Apple Inc
    "A8:60:B6"  # Apple Inc
    "B4:F0:AB"  # Apple Inc
    "3C:07:54"  # Apple Inc
    "68:5B:35"  # Apple Inc
    "00:3E:E1"  # Apple Inc
    "04:0C:CE"  # Apple Inc
    "80:E6:50"  # Apple Inc
    "B8:78:2E"  # Apple Inc
    "D0:81:7A"  # Apple Inc
    "F0:18:98"  # Apple Inc
    "F4:F1:5A"  # Apple Inc
    "F8:FF:C2"  # Apple Inc
    "00:16:CB"  # Apple Inc
    "8C:85:90"  # Apple Inc
    "00:26:08"  # Apple Inc
    "40:CB:C0"  # Apple Inc
    "90:72:40"  # Apple Inc
    "00:1E:C2"  # Apple Inc
    "00:26:BB"  # Apple Inc
    "78:CA:39"  # Apple Inc
    "A4:5E:60"  # Apple Inc
    "B8:09:8A"  # Apple Inc
    "D4:9A:20"  # Apple Inc
    "E0:AC:CB"  # Apple Inc
    "48:A1:95"  # Apple Inc
    "2C:F0:EE"  # ASUSTek Computer Inc
    "50:46:5D"  # ASUSTek Computer Inc
    "1C:87:2C"  # ASUSTek Computer Inc
    "04:D4:C4"  # ASUSTek Computer Inc
    "30:85:A9"  # ASUSTek Computer Inc
    "F4:B7:E2"  # ASUSTek Computer Inc
    "AC:9E:17"  # ASUSTek Computer Inc
    "18:31:BF"  # ASUSTek Computer Inc
    "B0:6E:BF"  # ASUSTek Computer Inc
    "00:15:58"  # ASUSTek Computer Inc
    "00:22:15"  # ASUSTek Computer Inc
    "00:24:8C"  # ASUSTek Computer Inc
    "18:C0:4D"  # SAMSUNG ELECTRO-MECHANICS
    "C8:BA:94"  # SAMSUNG ELECTRO-MECHANICS
    "E8:50:8B"  # SAMSUNG ELECTRO-MECHANICS
    "34:CF:F6"  # SAMSUNG ELECTRO-MECHANICS
    "5C:F9:DD"  # SAMSUNG ELECTRO-MECHANICS
    "88:32:9B"  # SAMSUNG ELECTRO-MECHANICS
    "30:07:4D"  # SAMSUNG ELECTRO-MECHANICS
    "00:26:37"  # SAMSUNG ELECTRO-MECHANICS
    "00:13:77"  # SAMSUNG ELECTRO-MECHANICS
    "00:16:32"  # SAMSUNG ELECTRO-MECHANICS
    "00:1D:25"  # SAMSUNG ELECTRO-MECHANICS
    "00:21:19"  # SAMSUNG ELECTRO-MECHANICS
    "00:23:39"  # SAMSUNG ELECTRO-MECHANICS
    "50:1A:C5"  # Acer Incorporated
    "00:02:3F"  # Acer Incorporated
    "00:0F:B0"  # Acer Incorporated
    "00:21:85"  # Acer Incorporated
    "88:AE:1D"  # Acer Incorporated
    "F0:76:1C"  # Acer Incorporated
    "28:92:4A"  # Acer Incorporated
    "C8:F7:33"  # Acer Incorporated
    "00:90:F5"  # DELL Inc
    "00:B0:D0"  # DELL Inc
    "00:C0:4F"  # DELL Inc
    "B4:96:91"  # DELL Inc
    "18:66:DA"  # DELL Inc
    "F0:1F:AF"  # DELL Inc
    "EC:F4:BB"  # DELL Inc
    "D4:BE:D9"  # DELL Inc
    "44:A8:42"  # DELL Inc
    "78:45:C4"  # DELL Inc
    "90:B1:1C"  # DELL Inc
    "E0:DB:55"  # DELL Inc
    "14:FE:B5"  # DELL Inc
    "00:14:22"  # DELL Inc
    "00:1A:A0"  # DELL Inc
    "00:21:70"  # DELL Inc
    "00:22:19"  # DELL Inc
    "00:23:AE"  # DELL Inc
    "00:24:E8"  # DELL Inc
    "00:26:B9"  # DELL Inc
    "A4:BA:DB"  # DELL Inc
    "5C:F9:38"  # DELL Inc
    "80:18:44"  # DELL Inc
    "34:17:EB"  # DELL Inc
    "C8:1F:66"  # DELL Inc
    "2C:76:8A"  # DELL Inc
    "50:9A:4C"  # DELL Inc
    "48:4D:7E"  # DELL Inc
    "18:03:73"  # DELL Inc
    "74:86:7A"  # DELL Inc
    "64:00:6A"  # DELL Inc
    "84:8F:69"  # DELL Inc
    "98:90:96"  # DELL Inc
    "3C:52:82"  # DELL Inc
    "00:08:74"  # DELL Inc
    "00:0D:56"  # DELL Inc
    "00:11:43"  # DELL Inc
    "00:12:3F"  # DELL Inc
    "00:13:72"  # DELL Inc
    "00:15:C5"  # DELL Inc
    "00:16:F0"  # DELL Inc
    "00:18:8B"  # DELL Inc
    "00:19:B9"  # DELL Inc
    "00:1C:23"  # DELL Inc  
    "00:1E:4F"  # DELL Inc
    "00:1F:C6"  # DELL Inc
    "5C:26:0A"  # Liteon Technology Corporation
    "9C:EB:E8"  # Liteon Technology Corporation
    "00:60:67"  # Realtek Semiconductor Corp
    "52:54:00"  # Realtek Semiconductor Corp
    "E8:DE:27"  # Realtek Semiconductor Corp
    "10:BF:48"  # Realtek Semiconductor Corp
    "50:E5:49"  # Realtek Semiconductor Corp
    "1C:39:47"  # Realtek Semiconductor Corp
    "A0:C5:89"  # Realtek Semiconductor Corp
    "E0:91:F5"  # Realtek Semiconductor Corp
    "54:E1:AD"  # Realtek Semiconductor Corp
    "C8:5B:76"  # Realtek Semiconductor Corp
    "18:DB:F2"  # Realtek Semiconductor Corp
    "FC:AA:B4"  # Realtek Semiconductor Corp
    "00:E0:4C"  # Realtek Semiconductor Corp
    "00:E0:4C"  # Realtek Semiconductor Corp
    "9C:5C:8E"  # Realtek Semiconductor Corp
    "74:DA:88"  # Realtek Semiconductor Corp
    "B0:25:AA"  # Realtek Semiconductor Corp
    "70:4D:7B"  # Realtek Semiconductor Corp
    "00:05:CD"  # D-Link Corporation
    "00:0D:88"  # D-Link Corporation
    "00:11:95"  # D-Link Corporation
    "00:13:46"  # D-Link Corporation
    "00:15:E9"  # D-Link Corporation
    "00:17:9A"  # D-Link Corporation
    "00:19:5B"  # D-Link Corporation
    "00:1B:11"  # D-Link Corporation
    "00:1C:F0"  # D-Link Corporation
    "00:1E:58"  # D-Link Corporation
    "00:21:91"  # D-Link Corporation
    "00:22:B0"  # D-Link Corporation
    "00:24:01"  # D-Link Corporation
    "00:26:5A"  # D-Link Corporation
    "14:D6:4D"  # D-Link Corporation
    "1C:7E:E5"  # D-Link Corporation
    "28:10:7B"  # D-Link Corporation
    "34:08:04"  # D-Link Corporation
    "40:61:86"  # D-Link Corporation
    "50:C7:BF"  # D-Link Corporation
    "54:B8:0A"  # D-Link Corporation
    "5C:D9:98"  # D-Link Corporation
    "78:54:2E"  # D-Link Corporation
    "7C:8B:CA"  # D-Link Corporation
    "84:C9:B2"  # D-Link Corporation
    "90:94:E4"  # D-Link Corporation
    "A0:AB:1B"  # D-Link Corporation
    "B8:A3:86"  # D-Link Corporation
    "C0:A0:BB"  # D-Link Corporation
    "C8:BE:19"  # D-Link Corporation
    "CC:B2:55"  # D-Link Corporation
    "E4:6F:13"  # D-Link Corporation
    "20:CF:30"  # ASRock Incorporation
    "70:85:C2"  # ASRock Incorporation
    "04:92:26"  # ASRock Incorporation
    "0C:C4:7A"  # ASRock Incorporation
    "1C:83:41"  # ASRock Incorporation
    "E0:3F:49"  # ASRock Incorporation
    "70:4C:A5"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:E0:FC"  # HUAWEI TECHNOLOGIES CO.,LTD
    "2C:AB:00"  # HUAWEI TECHNOLOGIES CO.,LTD
    "48:7B:6B"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C8:0E:14"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E0:19:1D"  # HUAWEI TECHNOLOGIES CO.,LTD
    "04:BD:88"  # HUAWEI TECHNOLOGIES CO.,LTD
    "18:4F:32"  # HUAWEI TECHNOLOGIES CO.,LTD
    "3C:DF:A9"  # HUAWEI TECHNOLOGIES CO.,LTD
    "64:16:8D"  # HUAWEI TECHNOLOGIES CO.,LTD
    "9C:28:EF"  # HUAWEI TECHNOLOGIES CO.,LTD
    "B0:91:34"  # HUAWEI TECHNOLOGIES CO.,LTD
    "B4:0B:44"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C4:0B:CB"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E8:C7:4F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:9A:CD"  # HUAWEI TECHNOLOGIES CO.,LTD
    "AC:37:43"  # HUAWEI TECHNOLOGIES CO.,LTD
    "24:44:27"  # HUAWEI TECHNOLOGIES CO.,LTD
    "28:6E:D4"  # HUAWEI TECHNOLOGIES CO.,LTD
    "80:71:7A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "EC:23:3D"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F4:07:AA"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F8:E6:1A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "20:47:DA"  # HUAWEI TECHNOLOGIES CO.,LTD
    "8C:34:FD"  # HUAWEI TECHNOLOGIES CO.,LTD
    "1C:1D:86"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A0:1D:48"  # HUAWEI TECHNOLOGIES CO.,LTD
    "D0:54:2D"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F0:79:59"  # HUAWEI TECHNOLOGIES CO.,LTD
    "BC:25:E0"  # HUAWEI TECHNOLOGIES CO.,LTD
    "10:44:00"  # HUAWEI TECHNOLOGIES CO.,LTD
    "4C:54:99"  # HUAWEI TECHNOLOGIES CO.,LTD
    "84:A8:E4"  # HUAWEI TECHNOLOGIES CO.,LTD
    "BC:76:70"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F0:B4:29"  # HUAWEI TECHNOLOGIES CO.,LTD
    "44:78:3E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "6C:4B:90"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:18:82"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:46:4B"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:74:9C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "58:2A:F7"  # HUAWEI TECHNOLOGIES CO.,LTD
    "5C:63:BF"  # HUAWEI TECHNOLOGIES CO.,LTD
    "68:BD:AB"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A4:C4:94"  # HUAWEI TECHNOLOGIES CO.,LTD
    "DC:D2:FC"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:1E:10"  # HUAWEI TECHNOLOGIES CO.,LTD
    "08:19:A6"  # HUAWEI TECHNOLOGIES CO.,LTD
    "0C:37:DC"  # HUAWEI TECHNOLOGIES CO.,LTD
    "3C:FA:43"  # HUAWEI TECHNOLOGIES CO.,LTD
    "6C:92:BF"  # HUAWEI TECHNOLOGIES CO.,LTD
    "98:54:1B"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A8:4C:A6"  # HUAWEI TECHNOLOGIES CO.,LTD
    "CC:E6:7F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "D8:49:2F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:25:9E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "1C:8E:5C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "38:BC:01"  # HUAWEI TECHNOLOGIES CO.,LTD
    "5C:E0:C5"  # HUAWEI TECHNOLOGIES CO.,LTD
    "98:0D:2E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C0:EE:FB"  # HUAWEI TECHNOLOGIES CO.,LTD
    "08:17:35"  # HUAWEI TECHNOLOGIES CO.,LTD
    "10:C6:1F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "40:4E:36"  # HUAWEI TECHNOLOGIES CO.,LTD
    "5C:C9:D3"  # HUAWEI TECHNOLOGIES CO.,LTD
    "88:CF:98"  # HUAWEI TECHNOLOGIES CO.,LTD
    "FC:48:EF"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:1F:E2"  # HUAWEI TECHNOLOGIES CO.,LTD
    "0C:96:E6"  # HUAWEI TECHNOLOGIES CO.,LTD
    "34:6B:D3"  # HUAWEI TECHNOLOGIES CO.,LTD
    "50:8F:4C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "94:04:9C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "B4:CD:27"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F4:4E:05"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:22:A1"  # HUAWEI TECHNOLOGIES CO.,LTD
    "4C:B1:6C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "9C:8E:DC"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C4:73:1E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "04:02:1F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "3C:8C:40"  # HUAWEI TECHNOLOGIES CO.,LTD
    "8C:25:05"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C8:94:BB"  # HUAWEI TECHNOLOGIES CO.,LTD
    "14:75:90"  # HUAWEI TECHNOLOGIES CO.,LTD
    "50:3D:E5"  # HUAWEI TECHNOLOGIES CO.,LTD
    "54:25:EA"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A4:50:46"  # HUAWEI TECHNOLOGIES CO.,LTD
    "CC:61:E5"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E8:BA:70"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F8:B4:6A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "3C:F8:62"  # HUAWEI TECHNOLOGIES CO.,LTD
    "BC:D0:74"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E4:E0:C1"  # HUAWEI TECHNOLOGIES CO.,LTD
    "54:89:98"  # HUAWEI TECHNOLOGIES CO.,LTD
    "78:D7:52"  # HUAWEI TECHNOLOGIES CO.,LTD
    "80:89:17"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A0:C5:F2"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C0:56:27"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E4:C2:D1"  # HUAWEI TECHNOLOGIES CO.,LTD
    "18:CF:5E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "28:3D:C2"  # HUAWEI TECHNOLOGIES CO.,LTD
    "60:DE:44"  # HUAWEI TECHNOLOGIES CO.,LTD
    "70:72:3C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "AC:E2:15"  # HUAWEI TECHNOLOGIES CO.,LTD
    "DC:F7:56"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F0:43:47"  # HUAWEI TECHNOLOGIES CO.,LTD
    "F4:55:95"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:66:4B"  # HUAWEI TECHNOLOGIES CO.,LTD
    "24:69:68"  # HUAWEI TECHNOLOGIES CO.,LTD
    "5C:01:97"  # HUAWEI TECHNOLOGIES CO.,LTD
    "90:67:1C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "B0:83:FE"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C4:F0:81"  # HUAWEI TECHNOLOGIES CO.,LTD
    "FC:5A:8A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "14:A5:1A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "60:83:34"  # HUAWEI TECHNOLOGIES CO.,LTD
    "8C:0F:6F"  # HUAWEI TECHNOLOGIES CO.,LTD
    "EC:A8:6B"  # HUAWEI TECHNOLOGIES CO.,LTD
    "3C:A9:F4"  # HUAWEI TECHNOLOGIES CO.,LTD
    "78:F5:FD"  # HUAWEI TECHNOLOGIES CO.,LTD
    "84:38:38"  # HUAWEI TECHNOLOGIES CO.,LTD
    "A8:7C:01"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E4:4E:2D"  # HUAWEI TECHNOLOGIES CO.,LTD
    "20:6B:E7"  # HUAWEI TECHNOLOGIES CO.,LTD
    "5C:A0:67"  # HUAWEI TECHNOLOGIES CO.,LTD
    "64:3E:8C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "94:DB:C9"  # HUAWEI TECHNOLOGIES CO.,LTD
    "B4:30:52"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C8:D1:5E"  # HUAWEI TECHNOLOGIES CO.,LTD
    "FC:B3:BC"  # HUAWEI TECHNOLOGIES CO.,LTD
    "08:7A:4C"  # HUAWEI TECHNOLOGIES CO.,LTD
    "4C:E1:73"  # HUAWEI TECHNOLOGIES CO.,LTD
    "98:48:27"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C4:29:4A"  # HUAWEI TECHNOLOGIES CO.,LTD
    "00:25:68"  # HUAWEI TECHNOLOGIES CO.,LTD
    "C4:0A:CB"  # HUAWEI TECHNOLOGIES CO.,LTD
    "E0:37:17"  # HUAWEI TECHNOLOGIES CO.,LTD
    "08:7C:14"  # LENOVO
    "68:F7:28"  # LENOVO
    "8C:B8:7A"  # LENOVO
    "C4:34:6B"  # LENOVO
    "E4:E7:49"  # LENOVO
    "00:21:CC"  # LENOVO
    "54:EE:75"  # LENOVO
    "B8:AC:6F"  # LENOVO
    "E8:11:32"  # LENOVO
    "1C:69:7A"  # LENOVO
    "50:65:F3"  # LENOVO
    "A4:4E:31"  # LENOVO
    "C8:1E:E7"  # LENOVO
    "00:23:24"  # LENOVO
    "20:68:9D"  # LENOVO
    "58:40:4E"  # LENOVO
    "A0:8C:FD"  # LENOVO
    "E8:6A:64"  # LENOVO
    "00:26:2D"  # LENOVO
    "40:F2:E9"  # LENOVO
    "5C:F3:70"  # LENOVO
    "98:4F:EE"  # LENOVO
    "DC:4A:3E"  # LENOVO
    "F0:DE:F1"  # LENOVO
    "10:1F:74"  # LENOVO
    "28:D2:44"  # LENOVO
    "54:27:1E"  # LENOVO
    "7C:1E:52"  # LENOVO
    "A4:C3:F0"  # LENOVO
    "CC:2F:71"  # LENOVO
    "E0:4F:43"  # LENOVO
    "F4:30:B9"  # LENOVO
    "60:6C:66"  # LENOVO
    "80:30:49"  # LENOVO
    "B0:52:16"  # LENOVO
    "D0:50:99"  # LENOVO
    "F8:B1:56"  # LENOVO
    "4C:79:6E"  # LENOVO
    "9C:B6:54"  # LENOVO
    "C0:38:96"  # LENOVO
    "E4:B3:18"  # LENOVO
    "00:21:9B"  # LENOVO
    "30:F9:ED"  # LENOVO
    "64:80:99"  # LENOVO
    "AC:22:0B"  # LENOVO
    "C4:85:08"  # LENOVO
    "F0:42:1C"  # LENOVO
    "2C:44:FD"  # LENOVO
    "48:65:EE"  # LENOVO
    "78:84:3C"  # LENOVO
    "B4:B6:86"  # LENOVO
    "DC:71:96"  # LENOVO
    "00:1C:25"  # LENOVO
    "3C:A8:2A"  # LENOVO
    "68:EC:C5"  # LENOVO
    "94:65:9C"  # LENOVO
    "C8:5A:CF"  # LENOVO
    "E4:A7:A0"  # LENOVO
    "18:66:DA"  # LENOVO
    "44:85:00"  # LENOVO
    "70:F1:A1"  # LENOVO
    "98:22:EF"  # LENOVO
    "C4:D9:87"  # LENOVO
    "E8:99:C4"  # LENOVO
    "04:7C:16"  # LENOVO
    "30:CD:A7"  # LENOVO
    "5C:80:B6"  # LENOVO
    "88:3F:D3"  # LENOVO
    "B4:2E:99"  # LENOVO
    "DC:41:A9"  # LENOVO
    "08:ED:B9"  # LENOVO
    "34:E6:D7"  # LENOVO
    "60:45:CB"  # LENOVO
    "8C:16:45"  # LENOVO
    "B8:CA:3A"  # LENOVO
    "E4:90:7E"  # LENOVO
    "0C:54:A5"  # LENOVO
    "38:2C:4A"  # LENOVO
    "64:00:F1"  # LENOVO
    "90:B6:86"  # LENOVO
    "BC:AE:C5"  # LENOVO
    "E8:6A:64"  # LENOVO
    "10:65:30"  # LENOVO
    "3C:52:82"  # LENOVO
    "68:F7:28"  # LENOVO
    "94:C6:91"  # LENOVO
    "C0:D0:12"  # LENOVO
    "EC:2E:98"  # LENOVO
    "14:4F:8A"  # LENOVO
    "40:B0:34"  # LENOVO
    "6C:4B:90"  # LENOVO
    "98:5A:EB"  # LENOVO
    "C4:54:44"  # LENOVO
    "F0:76:1C"  # LENOVO
    "18:31:BF"  # LENOVO
    "44:D8:84"  # LENOVO
    "70:F3:95"  # LENOVO
    "9C:B6:54"  # LENOVO
    "C8:1F:66"  # LENOVO
    "F4:06:69"  # LENOVO
)

# Dodatkowe prefiksy urządzeń IoT (nowe kategorie)
local smart_home_prefixes=(
    "18:FE:34"  # Xiaomi Communications Co Ltd (Mi IoT)
    "34:CE:00"  # Xiaomi Communications Co Ltd
    "50:EC:50"  # Xiaomi Communications Co Ltd
    "64:90:C1"  # Xiaomi Communications Co Ltd
    "78:11:DC"  # Xiaomi Communications Co Ltd
    "98:DA:C4"  # Xiaomi Communications Co Ltd
    "F0:B4:29"  # Xiaomi Communications Co Ltd
    "04:CF:8C"  # Xiaomi Communications Co Ltd
    "28:6C:07"  # Xiaomi Communications Co Ltd
    "4C:49:E3"  # Xiaomi Communications Co Ltd
    "7C:49:EB"  # Xiaomi Communications Co Ltd
    "A0:86:C6"  # Xiaomi Communications Co Ltd
    "F8:A4:5F"  # Xiaomi Communications Co Ltd
    "0C:1D:AF"  # Xiaomi Communications Co Ltd
    "34:80:B3"  # Xiaomi Communications Co Ltd
    "58:44:98"  # Xiaomi Communications Co Ltd
    "8C:BE:BE"  # Xiaomi Communications Co Ltd
    "B0:E2:35"  # Xiaomi Communications Co Ltd
    "F4:F5:DB"  # Xiaomi Communications Co Ltd
    "10:2A:B3"  # Xiaomi Communications Co Ltd
    "3C:28:6D"  # Xiaomi Communications Co Ltd
    "5C:02:14"  # Xiaomi Communications Co Ltd
    "90:67:1C"  # Xiaomi Communications Co Ltd
    "BC:DD:C2"  # Xiaomi Communications Co Ltd
    "F8:8F:CA"  # Xiaomi Communications Co Ltd
    "14:60:80"  # Xiaomi Communications Co Ltd
    "40:31:3C"  # Xiaomi Communications Co Ltd
    "6C:96:CF"  # Xiaomi Communications Co Ltd
    "98:0D:2E"  # Xiaomi Communications Co Ltd
    "C4:0B:CB"  # Xiaomi Communications Co Ltd
    "04:18:D6"  # TP-Link Technologies Co.,Ltd. (Smart Home)
    "14:CF:92"  # TP-Link Technologies Co.,Ltd.
    "1C:61:B4"  # TP-Link Technologies Co.,Ltd.
    "50:C7:BF"  # TP-Link Technologies Co.,Ltd.
    "68:FF:7B"  # TP-Link Technologies Co.,Ltd.
    "84:16:F9"  # TP-Link Technologies Co.,Ltd.
    "A4:2B:B0"  # TP-Link Technologies Co.,Ltd.
    "C0:25:E9"  # TP-Link Technologies Co.,Ltd.
    "EC:26:CA"  # TP-Link Technologies Co.,Ltd.
    "F4:F2:6D"  # TP-Link Technologies Co.,Ltd.
    "0C:80:63"  # TP-Link Technologies Co.,Ltd.
    "30:B5:C2"  # TP-Link Technologies Co.,Ltd.
    "54:AF:97"  # TP-Link Technologies Co.,Ltd.
    "7C:8B:CA"  # TP-Link Technologies Co.,Ltd.
    "A0:F3:C1"  # TP-Link Technologies Co.,Ltd.
    "C4:E9:84"  # TP-Link Technologies Co.,Ltd.
    "F0:9F:C2"  # TP-Link Technologies Co.,Ltd.
    "00:27:22"  # TP-Link Technologies Co.,Ltd.
    "1C:3B:F3"  # TP-Link Technologies Co.,Ltd.
    "48:8F:5A"  # TP-Link Technologies Co.,Ltd.
    "6C:5A:B0"  # TP-Link Technologies Co.,Ltd.
    "88:12:AC"  # TP-Link Technologies Co.,Ltd.
    "AC:84:C6"  # TP-Link Technologies Co.,Ltd.
    "D8:0D:17"  # TP-Link Technologies Co.,Ltd.
    "00:1B:2F"  # TP-Link Technologies Co.,Ltd.
    "20:F4:78"  # TP-Link Technologies Co.,Ltd.
    "4C:ED:FB"  # TP-Link Technologies Co.,Ltd.
    "70:4F:57"  # TP-Link Technologies Co.,Ltd.
    "94:10:3E"  # TP-Link Technologies Co.,Ltd.
    "B0:95:75"  # TP-Link Technologies Co.,Ltd.
    "D4:6E:0E"  # TP-Link Technologies Co.,Ltd.
    "F8:1A:67"  # TP-Link Technologies Co.,Ltd.
    "00:21:27"  # TP-Link Technologies Co.,Ltd.
    "24:A4:3C"  # TP-Link Technologies Co.,Ltd.
    "50:D4:F7"  # TP-Link Technologies Co.,Ltd.
    "74:DA:38"  # TP-Link Technologies Co.,Ltd.
    "98:48:27"  # TP-Link Technologies Co.,Ltd.
    "BC:46:99"  # TP-Link Technologies Co.,Ltd.
    "E0:28:6D"  # TP-Link Technologies Co.,Ltd.
    "18:D6:C7"  # Amazon Technologies Inc. (Echo, Fire devices)
    "44:65:0D"  # Amazon Technologies Inc.
    "6C:56:97"  # Amazon Technologies Inc.
    "8C:85:90"  # Amazon Technologies Inc.
    "B0:7B:25"  # Amazon Technologies Inc.
    "D4:F5:47"  # Amazon Technologies Inc.
    "F0:27:2D"  # Amazon Technologies Inc.
    "0C:47:C9"  # Amazon Technologies Inc.
    "38:F7:3D"  # Amazon Technologies Inc.
    "68:37:E9"  # Amazon Technologies Inc.
    "94:E6:7B"  # Amazon Technologies Inc.
    "C0:56:27"  # Amazon Technologies Inc.
    "FC:A6:67"  # Amazon Technologies Inc.
    "10:AE:60"  # TP-Link Technologies Co.,Ltd. (Tapo/Kasa)
    "34:12:F9"  # TP-Link Technologies Co.,Ltd.
    "5C:A6:E6"  # TP-Link Technologies Co.,Ltd.
    "80:EA:96"  # TP-Link Technologies Co.,Ltd.
    "A4:77:33"  # TP-Link Technologies Co.,Ltd.
    "C8:3A:35"  # TP-Link Technologies Co.,Ltd.
    "EC:71:DB"  # TP-Link Technologies Co.,Ltd.
    "14:EB:B6"  # TP-Link Technologies Co.,Ltd.
    "40:ED:00"  # TP-Link Technologies Co.,Ltd.
    "6C:B7:F4"  # TP-Link Technologies Co.,Ltd.
    "90:F6:52"  # TP-Link Technologies Co.,Ltd.
    "B4:B0:24"  # TP-Link Technologies Co.,Ltd.
    "D8:1C:79"  # TP-Link Technologies Co.,Ltd.
    "FC:EC:DA"  # TP-Link Technologies Co.,Ltd.
)

# Pierwszy sprawdź czy to nie jest laptop/komputer (wykluczenie)
for prefix in "${laptop_prefixes[@]}"; do
    if [[ ${mac^^} == ${prefix}* ]]; then
        device_type="Computer/Laptop"
        color_code="90" # ciemny szary dla komputerów
        echo "$device_type:$color_code"
        return
    fi
done

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

# Sprawdź urządzenia Smart Home
if [[ $device_type == "Unknown" ]]; then
    for prefix in "${smart_home_prefixes[@]}"; do
        if [[ ${mac^^} == ${prefix}* ]]; then
            device_type="Smart Home Device"
            color_code="33" # żółty
            break
        fi
    done
fi

# Jeśli nadal nieznane, sprawdź czy to IoT (ograniczone heurystyki)
if [[ $device_type == "Unknown" ]]; then
    # Sprawdź czy hostname sugeruje urządzenie IoT (bardziej restrykcyjne)
    local hostname=$(get_hostname "$ip")
    if [[ $hostname =~ ^(sensor|smart|home|iot|esp|arduino|raspi|pi|camera|bulb|switch|plug|thermostat)- ]]; then
        device_type="IoT Device"
        color_code="37" # szary
    fi
fi

echo "$device_type:$color_code"
}

scan_iot_devices() {
local interfaces iface type
local i=0
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "Wyszukiwanie IoT - Raspberry Pi, Arduino, Smart Home..."
echo ""

local found_iot=false

for iface in "${all_interfaces[@]}"; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    if [[ $state == "up" ]]; then
        mapfile -t devices < <(parse_arp_scan_results "$iface")
        for device in "${devices[@]}"; do
            if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                local ip_addr=$(echo "$device" | cut -d':' -f1)
                local mac_addr=$(echo "$device" | cut -d':' -f2-)
                if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                    local color_code=$(echo "$device_info" | cut -d':' -f2)

                    # Wyświetl TYLKO urządzenia IoT (nie Unknown i nie Computer/Laptop)
                    if [[ $device_type != "Unknown" && $device_type != "Computer/Laptop" ]]; then
                        local hn=$(get_hostname "$ip_addr")
                        print_color "$color_code" "Znaleziono $device_type: $hn (IP: $ip_addr ; MAC: $mac_addr)"
                        found_iot=true
                    fi
                fi
            fi
        done
    fi
done

if [[ $found_iot == false ]]; then
    print_color 37 "Brak urządzeń IoT do wyświetlenia"
fi

# Wyświetl informacje o znanych prefiksach MAC
echo ""
print_color 36 "Znane prefiksy MAC dla urządzeń IoT:"
print_color 95 "Raspberry Pi: 28:CD:C1, 2C:CF:67, B8:27:EB, D8:3A:DD, DC:A6:32, E4:5F:01"
print_color 34 "Arduino/ESP: 24:0A:C4, 30:AE:A4, 84:CC:A8, 8C:AA:B5, A0:20:A6, CC:50:E3, DC:4F:22, EC:FA:BC, 24:6F:28, 58:BF:25, 94:B9:7E"
print_color 33 "Smart Home: 18:FE:34 (Xiaomi), 04:18:D6 (TP-Link), 18:D6:C7 (Amazon), 10:AE:60 (TP-Link Tapo/Kasa)"
print_color 90 "Komputery/Laptopy: Wykluczane z wyników IoT (Apple, Dell, Lenovo, Asus, Samsung, Intel, Huawei itp.)"
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

# Funkcja do parsowania wyników arp-scan i zwracania IP i MAC z identyfikacją urządzeń
parse_arp_scan_results() {
local interface=$1
arp-scan --interface="$interface" --localnet 2>/dev/null | awk 'NR>2 && !/^Interface/ && !/^Starting/ && !/^Ending/ && !/packets/ && NF>=2 {print $1 ":" $2}'
}

# Dodana funkcja do skanowania urządzeń nieznanych (nie-IoT)
scan_unknown_devices() {
local interfaces iface type
local i=0
declare -a all_interfaces

mapfile -t all_interfaces < <(ls /sys/class/net | grep -v lo)

print_color 36 "Inne wykryte urządzenia sieciowe:"
echo ""

local found_other=false

for iface in "${all_interfaces[@]}"; do
    state=$(cat /sys/class/net/"$iface"/operstate 2>/dev/null || echo "unknown")
    if [[ $state == "up" ]]; then
        mapfile -t devices < <(parse_arp_scan_results "$iface")
        for device in "${devices[@]}"; do
            if [[ -n $device && $device != *"Interface"* && $device != *"Starting"* && $device != *"Ending"* && $device != *"packets"* ]]; then
                local ip_addr=$(echo "$device" | cut -d':' -f1)
                local mac_addr=$(echo "$device" | cut -d':' -f2-)
                if [[ -n $ip_addr && $ip_addr =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                    local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                    local device_type=$(echo "$device_info" | cut -d':' -f1)
                    local color_code=$(echo "$device_info" | cut -d':' -f2)

                    # Wyświetl urządzenia nieznane lub komputery/laptopy
                    if [[ $device_type == "Unknown" || $device_type == "Computer/Laptop" ]]; then
                        local hn=$(get_hostname "$ip_addr")
                        print_color "$color_code" "$hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
                        found_other=true
                    fi
                fi
            fi
        done
    fi
done

if [[ $found_other == false ]]; then
    print_color 37 "Brak innych urządzeń do wyświetlenia"
fi
echo ""
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

    # Skanowanie urządzeń Wi-Fi z wybranym interfejsem Wi-Fi z identyfikacją IoT
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
                            local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                            local device_type=$(echo "$device_info" | cut -d':' -f1)
                            local color_code=$(echo "$device_info" | cut -d':' -f2)

                            if [[ $device_type != "Unknown" ]]; then
                                print_color "$color_code" " $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
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

    # Skanowanie urządzeń LAN z wybranym interfejsem LAN z identyfikacją IoT
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
                            local device_info=$(identify_device_type "$mac_addr" "$ip_addr")
                            local device_type=$(echo "$device_info" | cut -d':' -f1)
                            local color_code=$(echo "$device_info" | cut -d':' -f2)
                            if [[ $device_type != "Unknown" ]]; then
                                print_color "$color_code" " +---[LAN]---> $hn [$device_type] (IP: $ip_addr ; MAC: $mac_addr)"
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
    mapfile -t nmcli_interfaces < <(nmcli -t -f DEVICE con show --active | cut -d':' -f1 | grep -v '^)
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
    mapfile -t ordered_interfaces < <(ls /sys/class/net |