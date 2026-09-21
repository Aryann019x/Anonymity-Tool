#!/bin/bash
# ───────────────────────────────────────────────────────────────────────────
# Anonymity Tool Anonyx v1.2
# Kali Linux
# Created by Aryann019x
# A robust tool for anonymous operations
# ───────────────────────────────────────────────────────────────────────────

VERSION="1.2"
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
RESOLV_BAK="/etc/resolv.conf.bak.anonyx"
TOR_CONF="/etc/tor/torrc"
TOR_BAK="/etc/tor/torrc.bak.anonyx"
PROXY_BAK="/etc/proxychains4.conf.bak.anonyx"

# Error handling - just log it, dont spam on expected fails
handle_error() {
    echo -e "${YELLOW}⚠ Warning at line $1: $2${RESET}"
    return $3
}

# Check root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}${BOLD}✖ Run as root: sudo $0${RESET}"
        exit 1
    fi
}

# Initialize logging
init_logging() {
    mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
    exec 1> >(tee -a "$LOG_FILE")
    exec 2> >(tee -a "$LOG_FILE" >&2)
    chmod 600 "$LOG_FILE" 2>/dev/null
    echo -e "\n${BLUE}${BOLD}=== Session Started: $(date) ===${RESET}"
}

# backup file once, dont overwrite good backup
backup_once() {
    if [[ -f "$1" && ! -f "$2" ]]; then
        cp "$1" "$2" 2>/dev/null
    fi
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
    # ping is blocked on some networks, try curl as fallback
    if check_cmd curl >/dev/null 2>&1 && curl --max-time 5 -s https://1.1.1.1 >/dev/null 2>&1; then
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
    backup_once "$TOR_CONF" "$TOR_BAK"
    cat > "$TOR_CONF" << EOF
SocksPort $TOR_PORT
ControlPort $CONTROL_PORT
DataDirectory /var/lib/tor
RunAsDaemon 1
EOF
    chmod 644 "$TOR_CONF"
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl restart tor
    else
        service tor restart
    fi
    sleep 3
}

# Configure ProxyChains
setup_proxychains() {
    echo -e "${WHITE}🔹 Configuring ProxyChains...${RESET}"
    backup_once "$PROXYCHAINS_CONF" "$PROXY_BAK"
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
        if curl --max-time 15 --socks5 127.0.0.1:$TOR_PORT -s "https://check.torproject.org/api/ip" | grep -q '"IsTor":true'; then
            echo -e "${GREEN}✓ Tor connection verified${RESET}"
            return 0
        fi
        ((attempts++))
        echo -e "${WHITE}retrying... ($attempts/3)${RESET}"
        sleep 5
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

    # dont run twice by mistake
    if [[ -f "$RESOLV_BAK" ]] && grep -q "1.1.1.1" "$RESOLV_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Anonymity already looks enabled${RESET}"
    fi

    echo -e "${BLUE}${BOLD}🔹 Enabling anonymity mode...${RESET}"

    install_packages || {
        echo -e "${RED}✖ Setup aborted, packages missing${RESET}"
        return 1
    }

    backup_once "$RESOLV_FILE" "$RESOLV_BAK"
    printf "nameserver %s\n" "${DNS_SERVERS[@]}" > "$RESOLV_FILE"

    setup_tor
    setup_proxychains

    # make sure firewall is on, tor socks is local only so no need to open ports
    echo -e "${WHITE}🔹 Configuring firewall...${RESET}"
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable >/dev/null 2>&1 || true
    fi

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

    [[ -f "$RESOLV_BAK" ]] && mv "$RESOLV_BAK" "$RESOLV_FILE" 2>/dev/null
    [[ -f "$TOR_BAK" ]] && mv "$TOR_BAK" "$TOR_CONF" 2>/dev/null
    [[ -f "$PROXY_BAK" ]] && mv "$PROXY_BAK" "$PROXYCHAINS_CONF" 2>/dev/null

    if [[ -f "$TOR_CONF" ]]; then
        if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
            systemctl restart tor 2>/dev/null || systemctl stop tor 2>/dev/null || true
        else
            service tor restart 2>/dev/null || service tor stop 2>/dev/null || true
        fi
    else
        systemctl stop tor 2>/dev/null || service tor stop 2>/dev/null || true
    fi

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
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl is-active --quiet tor && tor_status="active"
    else
        pgrep -x tor >/dev/null 2>&1 && tor_status="active"
    fi
    printf "${WHITE}%-20s: %s${RESET}\n" "Tor Service" "$tor_status"

    if [[ "$tor_status" == "active" ]]; then
        local tor_ip=$(curl --max-time 10 --socks5 127.0.0.1:$TOR_PORT -s "https://check.torproject.org/api/ip" 2>/dev/null | grep -o '"IP":"[^"]*' | cut -d'"' -f4)
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

        read -rp "Select option [1-4]: " choice
        case $choice in
            1) enable_anon ;;
            2) disable_anon ;;
            3) show_status ;;
            4) exit 0 ;;
            *) echo -e "${RED}✖ Invalid option${RESET}" ;;
        esac
        read -rp "Press Enter to continue..." _
    done
}

show_help() {
    echo "Usage: sudo ./Anonyx.sh [--enable|--disable|--status|--help]"
    echo "  no args      open menu"
    echo "  --enable     enable anonymity"
    echo "  --disable    restore normal settings"
    echo "  --status     show tor + dns status"
}

# Main execution
check_root
init_logging
INTERFACE=$(get_interface)
trap cleanup EXIT

case "${1:-}" in
    --enable|-e) enable_anon; exit $? ;;
    --disable|-d) disable_anon; exit $? ;;
    --status|-s) show_status; exit 0 ;;
    --help|-h) show_help; exit 0 ;;
    "") main_menu ;;
    *) echo -e "${RED}✖ Unknown option: $1${RESET}"; show_help; exit 1 ;;
esac
