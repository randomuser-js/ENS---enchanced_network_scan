#!/bin/bash

# Enhanced Network Scanner (ENS) v1.4
# This script performs network discovery, mapping, and analysis.

# --- Configuration ---
OUTPUT_DIR="/tmp/ens_reports"
LOG_FILE="$OUTPUT_DIR/ens_log.txt"
REPORT_FILE="$OUTPUT_DIR/network_report.txt"
TOPOLOGY_FILE="$OUTPUT_DIR/network_topology.txt"
DEVICE_DETAILS_FILE="$OUTPUT_DIR/device_details.txt"

# --- Colors for better output ---
RED='
[0;31m'
GREEN='
[0;32m'
YELLOW='
[0;33m'
BLUE='
[0;34m'
NC='
[0m' # No Color

# --- Functions ---

log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

display_header() {
    clear
    echo -e "${BLUE}####################################################${NC}"
    echo -e "${BLUE}#         Enhanced Network Scanner (ENS) v1.4      #${NC}"
    echo -e "${BLUE}#             Network Discovery & Mapping          #${NC}"
    echo -e "${BLUE}####################################################${NC}"
    echo ""
}

check_dependencies() {
    local missing_deps=()
    for cmd in nmap arp-scan traceroute; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_message "${RED}Error: The following required commands are not installed: ${missing_deps[*]}.${NC}"
        log_message "${RED}Please install them using your system's package manager (e.g., sudo apt install ${missing_deps[*]} or sudo dnf install ${missing_deps[*]}).${NC}"
        exit 1
    fi
    log_message "${GREEN}All required dependencies are installed.${NC}"
}

create_output_dir() {
    mkdir -p "$OUTPUT_DIR"
    if [ $? -eq 0 ]; then
        log_message "${GREEN}Output directory created: $OUTPUT_DIR${NC}"
    else
        log_message "${RED}Error: Could not create output directory: $OUTPUT_DIR${NC}"
        exit 1
    fi
}

get_local_ip() {
    # Get the IP address of the primary network interface
    # This tries to get the IP that would be used to reach the internet
    LOCAL_IP=$(ip route get 1.1.1.1 | awk '{print $7}' | head -n 1)
    if [ -z "$LOCAL_IP" ]; then
        log_message "${RED}Error: Could not determine local IP address.${NC}"
        exit 1
    }
    log_message "${GREEN}Local IP address detected: $LOCAL_IP${NC}"
}

get_subnet() {
    # Get the subnet in CIDR notation
    SUBNET=$(ip -o -f inet addr show | awk '/scope global/ {print $4}' | head -n 1)
    if [ -z "$SUBNET" ]; then
        log_message "${RED}Error: Could not determine subnet.${NC}"
        exit 1
    }
    log_message "${GREEN}Subnet detected: $SUBNET${NC}"
}

perform_lan_scan() {
    log_message "${YELLOW}Starting LAN device discovery using arp-scan...${NC}"
    log_message "${YELLOW}Note: arp-scan requires root privileges. You may be prompted for your password.${NC}"
    log_message "${YELLOW}If no devices are found, ensure you have sufficient permissions and arp-scan is working correctly.${NC}"

    # Use arp-scan to find devices on the local network
    # -l: local network
    # -q: quiet mode (suppress output for each host found)
    # -t: timeout for each host
    # --interface: specify interface (optional, arp-scan usually picks the right one)
    # --localnet: scan local network
    LAN_DEVICES=$(sudo arp-scan --localnet | grep -E '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | awk '{print $1, $2}')

    if [ -z "$LAN_DEVICES" ]; then
        log_message "${RED}No devices found on the local network using arp-scan. This might indicate a permission issue or no active devices.${NC}"
        echo "No devices found on the local network." > "$REPORT_FILE"
        return 1
    else
        log_message "${GREEN}LAN scan completed. Found devices:${NC}"
        echo "$LAN_DEVICES" | while read -r ip mac; do
            log_message "  IP: $ip, MAC: $mac"
        done
        echo "--- LAN Devices ---" > "$REPORT_FILE"
        echo "$LAN_DEVICES" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    }
}

perform_nmap_scan() {
    log_message "${YELLOW}Starting Nmap scan for open ports and services on detected LAN devices...${NC}"
    echo "--- Nmap Scan Results (Open Ports & Services) ---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    echo "$LAN_DEVICES" | while read -r ip mac; do
        log_message "Scanning $ip ($mac)..."
        echo "Host: $ip ($mac)" >> "$REPORT_FILE"
        # -sS: SYN scan (stealth)
        # -sV: Service version detection
        # -O: OS detection
        # -T4: Faster execution
        # --open: Only show open ports
        NMAP_RESULT=$(nmap -sS -sV -O -T4 --open "$ip")
        echo "$NMAP_RESULT" >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
        echo "$NMAP_RESULT" | grep -E '^[0-9]+/(tcp|udp)' | while read -r line; do
            echo "$ip,$mac,$line" >> "$DEVICE_DETAILS_FILE"
        done
    done
    log_message "${GREEN}Nmap scan completed. Results saved to $REPORT_FILE and $DEVICE_DETAILS_FILE.${NC}"
}

map_network_topology() {
    log_message "${YELLOW}Mapping network topology using traceroute...${NC}"
    echo "--- Network Topology ---" > "$TOPOLOGY_FILE"
    echo "" >> "$TOPOLOGY_FILE"

    # Get default gateway
    GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n 1)
    if [ -z "$GATEWAY" ]; then
        log_message "${RED}Could not determine default gateway. Topology mapping might be incomplete.${NC}"
    else
        log_message "${GREEN}Default Gateway: $GATEWAY${NC}"
        echo "Default Gateway: $GATEWAY" >> "$TOPOLOGY_FILE"
    }

    echo "" >> "$TOPOLOGY_FILE"
    echo "Local Network (LAN):" >> "$TOPOLOGY_FILE"
    echo "  Your Device ($LOCAL_IP)" >> "$TOPOLOGY_FILE"
    
    # Use printf for better alignment of ASCII art
    printf "%s
" "  |" >> "$TOPOLOGY_FILE"
    printf "%s
" "  +-- Gateway ($GATEWAY)" >> "$TOPOLOGY_FILE"
    printf "%s
" "  |" >> "$TOPOLOGY_FILE"

    echo "$LAN_DEVICES" | while read -r ip mac; do
        if [ "$ip" != "$LOCAL_IP" ] && [ "$ip" != "$GATEWAY" ]; then
            printf "%s
" "  +-- $ip ($mac)" >> "$TOPOLOGY_FILE"
        fi
    done
    echo "" >> "$TOPOLOGY_FILE"

    echo "External Connections (Traceroute to common external hosts):" >> "$TOPOLOGY_FILE"
    EXTERNAL_HOSTS=("8.8.8.8" "google.com" "github.com") # Common external hosts

    for host in "${EXTERNAL_HOSTS[@]}"; do
        log_message "Tracerouting to $host..."
        echo "Traceroute to $host:" >> "$TOPOLOGY_FILE"
        TRACEROUTE_RESULT=$(traceroute -n -q 1 -w 1 "$host" 2>&1) # -n: no DNS, -q 1: 1 query, -w 1: 1 sec wait
        echo "$TRACEROUTE_RESULT" >> "$TOPOLOGY_FILE"
        echo "" >> "$TOPOLOGY_FILE"

        # Extracting NAT/device relationships from traceroute
        echo "--- NAT/Device Relationship for $host ---" >> "$REPORT_FILE"
        echo "Traceroute to $host:" >> "$REPORT_FILE"
        echo "$TRACEROUTE_RESULT" | awk '
            /^[[:space:]]*[0-9]+/ {
                if ($2 == "*") {
                    print "  Hop " $1 ": Request timed out (possible firewall/NAT)"
                } else {
                    print "  Hop " $1 ": " $2
                }
            }
        ' >> "$REPORT_FILE"
        echo "" >> "$REPORT_FILE"
    done
    log_message "${GREEN}Network topology mapping completed. Results saved to $TOPOLOGY_FILE and $REPORT_FILE.${NC}"
}

generate_summary_report() {
    log_message "${YELLOW}Generating final summary report...${NC}"
    echo -e "${BLUE}####################################################${NC}" >> "$REPORT_FILE"
    echo -e "${BLUE}#         Enhanced Network Scanner (ENS) v1.4      #${NC}" >> "$REPORT_FILE"
    echo -e "${BLUE}#                 Summary Report                   #${NC}" >> "$REPORT_FILE"
    echo -e "${BLUE}####################################################${NC}" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$REPORT_FILE"
    echo "Local IP: $LOCAL_IP" >> "$REPORT_FILE"
    echo "Subnet: $SUBNET" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    echo "--- All Detected Devices (IP, MAC, Open Ports, Services) ---" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    if [ -f "$DEVICE_DETAILS_FILE" ]; then
        # Sort and unique the device details for a cleaner report
        sort -u "$DEVICE_DETAILS_FILE" | awk -F',' '
            BEGIN {
                current_ip = "";
                print "IP Address\tMAC Address\tPort/Service";
                print "----------------------------------------------------";
            }
            {
                if ($1 != current_ip) {
                    if (current_ip != "") {
                        print ""; # Add a blank line between different IPs
                    }
                    current_ip = $1;
                    printf "%s\t%s\n", $1, $2;
                }
                # Print port and service details, handling potential empty service info
                if ($3 != "") {
                    printf "\t\t%s\n", $3;
                }
            }
            END {
                print "----------------------------------------------------";
            }
        ' >> "$REPORT_FILE"
    else
        echo "No detailed device information collected." >> "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"

    echo "--- Network Topology Overview ---" >> "$REPORT_FILE"
    cat "$TOPOLOGY_FILE" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"

    log_message "${GREEN}Summary report generated: $REPORT_FILE${NC}"
}

# --- Main Execution ---
display_header
create_output_dir
check_dependencies
get_local_ip
get_subnet

# Clear previous device details file
> "$DEVICE_DETAILS_FILE"

perform_lan_scan
if [ $? -eq 0 ]; then # Only proceed if LAN scan found devices
    perform_nmap_scan
fi
map_network_topology
generate_summary_report

log_message "${GREEN}ENS scan completed!${NC}"
log_message "${GREEN}Reports are available in: $OUTPUT_DIR${NC}"
log_message "${GREEN}Check $REPORT_FILE for the full summary.${NC}"
log_message "${GREEN}Check $TOPOLOGY_FILE for network topology details.${NC}"
log_message "${GREEN}Check $LOG_FILE for execution logs.${NC}"
log_message "${GREEN}Check $DEVICE_DETAILS_FILE for raw device details.${NC}"

echo ""
echo -e "${GREEN}Scan finished. Press any key to exit.${NC}"
read -n 1 -s
