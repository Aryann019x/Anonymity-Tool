#!/bin/bash
# ───────────────────────────────────────────────────────────────────────────
# Anonymity Tool Anonyx v1.1
# Kali Linux
# Created by Aryann019x
# A robust tool for anonymous operations
# ───────────────────────────────────────────────────────────────────────────

VERSION="1.1v"
TOR_PORT=9050
CONTROL_PORT=9051
DNS_SERVERS=("1.1.1.1" "9.9.9.9" "208.67.222.222")

# Colors
BLUE="\e[34m"
LAVENDER="\e[35m"
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
WHITE="\e[97m"
RESET="\e[0m"
BOLD="\e[1m"

# Files
LOG_FILE="/var/log/anonymity.log"
PROXYCHAINS_CONF="/etc/proxychains4.conf"
RESOLV_FILE="/etc/resolv.conf"
RESOLV_BAK="/etc/resolv.conf.bak"
TOR_CONF="/etc/tor/torrc"

# Error handling
handle_error() {
    echo -e "${YELLOW}⚠ Warning at line $1: $2${RESET}"
    return $3
}
trap 'handle_error $LINENO "$BASH_COMMAND" $?' ERR

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}✖ Run as root: sudo $0${RESET}"
        exit 1
    fi
}

# Initialize logging
init_logging() {
    mkdir -p $(dirname "$LOG_FILE") 2>/dev/null
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    chmod 600 "$LOG_FILE" 2>/dev/null
    echo -e "\n${BLUE}${BOLD}=== Session Started: $(date) ===${RESET}"
}

# Get network interface
get_interface() {
    local iface=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z "$iface" ]]; then
        iface=$(ip link | grep -E "^[0-9]+: (eth|wlan|enp|wlp)" | head -n1 | awk -F: '{print $2}' | tr -d ' ')
    fi
    echo "${iface:-lo}"
}

# Check commands
check_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo -e "${RED}✖ Command $1 not found${RESET}"
        return 1
    }
}

# Check internet
check_internet() {
    echo -e "${WHITE}🔹 Checking internet connection...${RESET}"
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 || ping -c 1 -W 5 1.1.1.1 >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Install packages
install_packages() {
    echo -e "${WHITE}🔹 Installing required packages...${RESET}"
    apt-get update -qq || true
    apt-get install -y tor proxychains4 torsocks curl ufw >/dev/null 2>&1 || {
        echo -e "${RED}✖ Package installation failed${RESET}"
        return 1
    }
}

# Configure Tor
setup_tor() {
    echo -e "${WHITE}🔹 Setting up Tor...${RESET}"
    mkdir -p /etc/tor
    cat > "$TOR_CONF" << EOF
SocksPort $TOR_PORT
ControlPort $CONTROL_PORT
DataDirectory /var/lib/tor
RunAsDaemon 1
EOF
    chmod 644 "$TOR_CONF"
    systemctl restart tor || service tor restart
    sleep 3
}

# Configure ProxyChains
setup_proxychains() {
    echo -e "${WHITE}🔹 Configuring ProxyChains...${RESET}"
    cat > "$PROXYCHAINS_CONF" << EOF
strict_chain
proxy_dns
remote_dns_subnet 224
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
socks5 127.0.0.1 $TOR_PORT
EOF
    chmod 644 "$PROXYCHAINS_CONF"
}

# Verify Tor
check_tor() {
    echo -e "${WHITE}🔹 Verifying Tor...${RESET}"
    local attempts=0
    while ((attempts < 3)); do
        if curl --socks5 localhost:$TOR_PORT -s "https://check.torproject.org/api/ip" | grep -q '"IsTor":true'; then
            echo -e "${GREEN}✓ Tor connection verified${RESET}"
            return 0
        fi
        ((attempts++))
        sleep 3
    done
    echo -e "${RED}✖ Tor verification failed${RESET}"
    return 1
}

# Enable anonymity
enable_anon() {
    if ! check_internet; then
        echo -e "${RED}✖ No internet connection${RESET}"
        return 1
    fi

    echo -e "${BLUE}${BOLD}🔹 Enabling anonymity mode...${RESET}"
    
    install_packages
    cp "$RESOLV_FILE" "$RESOLV_BAK" 2>/dev/null
    printf "nameserver %s\n" "${DNS_SERVERS[@]}" > "$RESOLV_FILE"
    
    setup_tor
    setup_proxychains
    
    # Enable UFW and allow Tor ports
    echo -e "${WHITE}🔹 Configuring firewall...${RESET}"
    sudo ufw enable
    sudo ufw allow 9050/tcp
    sudo ufw allow 9051/tcp

    if check_tor; then
        echo -e "${GREEN}✓ Anonymity enabled${RESET}"
        show_status
        return 0
    else
        echo -e "${RED}✖ Setup failed${RESET}"
        disable_anon
        return 1
    fi
}

# Disable anonymity
disable_anon() {
    echo -e "${BLUE}${BOLD}🔹 Disabling anonymity mode...${RESET}"
    
    [[ -f "$RESOLV_BAK" ]] && mv "$RESOLV_BAK" "$RESOLV_FILE"
    systemctl stop tor 2>/dev/null || service tor stop 2>/dev/null

    # Delete UFW rules for Tor ports
    echo -e "${WHITE}🔹 Configuring firewall...${RESET}"
    sudo ufw delete allow 9050/tcp
    sudo ufw delete allow 9051/tcp

    if check_internet; then
        echo -e "${GREEN}✓ Normal mode restored${RESET}"
    else
        echo -e "${YELLOW}⚠ Check network settings${RESET}"
    fi
}

# Show status
show_status() {
    echo -e "${BLUE}${BOLD}════════════ System Status ════════════${RESET}"
    printf "${WHITE}%-20s: %s${RESET}\n" "Version" "$VERSION"
    printf "${WHITE}%-20s: %s${RESET}\n" "Interface" "$INTERFACE"
    
    local tor_status="inactive"
    pgrep -x tor >/dev/null && tor_status="active"
    printf "${WHITE}%-20s: %s${RESET}\n" "Tor Service" "$tor_status"
    
    if [[ "$tor_status" == "active" ]]; then
        local tor_ip=$(curl --socks5 localhost:$TOR_PORT -s "https://check.torproject.org/api/ip" 2>/dev/null | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
        [[ -n "$tor_ip" ]] && printf "${WHITE}%-20s: %s${RESET}\n" "Tor IP" "$tor_ip"
    fi
    
    printf "${WHITE}%-20s: %s${RESET}\n" "DNS Servers" "$(grep nameserver "$RESOLV_FILE" 2>/dev/null | cut -d' ' -f2 | tr '\n' ' ')"
    echo -e "${BLUE}${BOLD}═══════════════════════════════════════${RESET}"
}

# Cleanup
cleanup() {
    echo -e "\n${BLUE}${BOLD}=== Session Ended: $(date) ===${RESET}"
}

# Main menu
main_menu() {
    while true; do
        clear
        echo -e "${BLUE}${BOLD}════════════════════════════════════${RESET}"
        echo -e "${BLUE}${BOLD}  Anonymity Tool Anonyx ${VERSION} ${RESET}"
        echo -e "${BLUE}  Created by: ${BOLD}${LAVENDER}Aryann019x${RESET}"
        echo -e "${BLUE}${BOLD}════════════════════════════════════${RESET}"
        echo -e "${WHITE}[1] Enable Anonymity"
        echo -e "[2] Disable Anonymity"
        echo -e "[3] Show Status"
        echo -e "[4] Exit${RESET}"
        echo -e "${BLUE}${BOLD}════════════════════════════════════${RESET}"
        
        read -p "Select option [1-4]: " choice
        case $choice in
            1) enable_anon ;;
            2) disable_anon ;;
            3) show_status ;;
            4) exit 0 ;;
            *) echo -e "${RED}✖ Invalid option${RESET}" ;;
        esac
        read -p "Press Enter to continue..."
    done
}

# Main execution
check_root
init_logging
INTERFACE=$(get_interface)
trap cleanup EXIT
main_menu
