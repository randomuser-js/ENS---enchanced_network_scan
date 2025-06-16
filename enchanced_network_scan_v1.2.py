# nie działa!


def print_network_architecture():
    gw_ip, vendor, model = get_router_info()
    ifaces = interfaces()

    wifi_ifaces = [iface for iface in ifaces if interface_type(iface) == "Wi-Fi"]
    lan_ifaces = [iface for iface in ifaces if interface_type(iface) == "LAN-Ethernet"]

    print_color("\n[Internet]", 36)
    print("    |")
    print_color(" [Router]", 35)
    print_color(f"  IP: {gw_ip}", 35)
    print_color(f"  Vendor: {vendor}", 35)
    print_color(f"  Model: {model}", 35)
    print("    |")
    print("   / \\")
    print("  /   \\")

    # Wi-Fi branch
    if wifi_ifaces:
        wifi_iface = wifi_ifaces[0]
        ip_wifi = interface_ip(wifi_iface)
        ssid = run_cmd(f"iw dev {wifi_iface} link | grep SSID | awk '{{print $2}}'") or "Brak SSID"
        print_color(f" /     \\ Wi-Fi: {wifi_iface} (SSID: {ssid}, IP: {ip_wifi})", 33)

        # podłączone urządzenia (arp-scan)
        try:
            output = subprocess.check_output(
                ["sudo", "arp-scan", "--interface", wifi_iface, "--localnet"], text=True)
            devices = []
            for line in output.splitlines()[2:-3]:
                parts = line.split()
                if len(parts) >= 2:
                    ip_dev = parts[0]
                    hn = get_hostname(ip_dev)
                    devices.append(f"{hn} ({ip_dev})")
            if devices:
                print_color("  Connected Wi-Fi devices:", 33)
                for d in devices:
                    print_color(f"   |-- {d}", 33)
            else:
                print_color("  No Wi-Fi devices found.", 33)
        except Exception:
            print_color("  arp-scan failed or no Wi-Fi devices.", 31)
    else:
        print_color(" /     \\ No Wi-Fi interfaces found.", 31)

    # LAN branch
    if lan_ifaces:
        lan_iface = lan_ifaces[0]
        ip_lan = interface_ip(lan_iface)
        print_color(f" \\     / LAN: {lan_iface} (IP: {ip_lan})", 32)
        # Urządzenia w LAN
        try:
            output = subprocess.check_output(
                ["sudo", "arp-scan", "--interface", lan_iface, "--localnet"], text=True)
            devices = []
            for line in output.splitlines()[2:-3]:
                parts = line.split()
                if len(parts) >= 2:
                    ip_dev = parts[0]
                    hn = get_hostname(ip_dev)
                    devices.append(f"{hn} ({ip_dev})")
            if devices:
                print_color("  Connected LAN devices:", 32)
                for d in devices:
                    print_color(f"   |-- {d}", 32)
            else:
                print_color("  No LAN devices found.", 32)
        except Exception:
            print_color("  arp-scan failed or no LAN devices.", 31)
    else:
        print_color(" \\     / No LAN interfaces found.", 31)

    print()

# W `main()` na końcu po skanowaniu dodaj:
# print_network_architecture()
