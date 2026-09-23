#!/bin/bash
# ───────────────────────────────────────────────────────────────────────────
# Anonymity Tool Anonyx v2.2
# Kali Linux
# Created by Aryann019x
# A robust tool for anonymous operations
# Note: no tool gives 100% privacy, this just makes leaks much harder
# ───────────────────────────────────────────────────────────────────────────

VERSION="2.2"
TOR_PORT=9050
CONTROL_PORT=9051
DNS_PORT=5353
TRANS_PORT=9040
# kept for reference only: all dns now resolves via tor, nothing uses these directly
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
STATE_DIR="/var/lib/anonyx"
STATE_FILE="$STATE_DIR/state"
IPT_BAK="$STATE_DIR/iptables.bak"
IP6T_BAK="$STATE_DIR/ip6tables.bak"
CLEAR_IP_FILE="$STATE_DIR/clear_ip"

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
    apt-get install -y tor proxychains4 torsocks curl ufw iptables iproute2 >/dev/null 2>&1 || {
        echo -e "${RED}✖ Package installation failed${RESET}"
        return 1
    }
}

# tor user for killswitch (debian-tor on debian/kali, tor on some)
get_tor_uid() {
    id -u debian-tor 2>/dev/null || id -u tor 2>/dev/null || echo ""
}

have_iptables() {
    command -v iptables >/dev/null 2>&1
}

# Configure Tor
setup_tor() {
    echo -e "${WHITE}🔹 Setting up Tor...${RESET}"
    mkdir -p /etc/tor
    backup_once "$TOR_CONF" "$TOR_BAK"
    cat > "$TOR_CONF" << EOF
SocksPort 127.0.0.1:$TOR_PORT IsolateDestAddr IsolateDestPort
DNSPort 127.0.0.1:$DNS_PORT
TransPort 127.0.0.1:$TRANS_PORT
ControlPort $CONTROL_PORT
DataDirectory /var/lib/tor
RunAsDaemon 1
CookieAuthentication 1
AvoidDiskWrites 1
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
SocksPolicy accept 127.0.0.1
SocksPolicy reject *
EOF
    chmod 644 "$TOR_CONF"
    mkdir -p "$STATE_DIR"
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

# dns goes through tor itself: localhost only, locked so nothing can revert it
lock_dns() {
    printf "nameserver 127.0.0.1\n" > "$RESOLV_FILE"
    chattr +i "$RESOLV_FILE" 2>/dev/null || true
}

unlock_dns() {
    chattr -i "$RESOLV_FILE" 2>/dev/null || true
}

# block ipv6, it bypasses tor socks
disable_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1 || true
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -P INPUT DROP 2>/dev/null || true
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT DROP 2>/dev/null || true
    fi
}

restore_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=0 >/dev/null 2>&1 || true
    sysctl -w net.ipv6.conf.default.disable_ipv6=0 >/dev/null 2>&1 || true
    if [[ -f "$IP6T_BAK" ]] && command -v ip6tables-restore >/dev/null 2>&1; then
        ip6tables-restore < "$IP6T_BAK" 2>/dev/null || true
    else
        if command -v ip6tables >/dev/null 2>&1; then
            ip6tables -P INPUT ACCEPT 2>/dev/null || true
            ip6tables -P FORWARD ACCEPT 2>/dev/null || true
            ip6tables -P OUTPUT ACCEPT 2>/dev/null || true
            ip6tables -F 2>/dev/null || true
        fi
    fi
}

# killswitch + transparent proxy: all tcp/dns forced through tor, rest dropped
enable_killswitch() {
    echo -e "${WHITE}🔹 Enabling kill-switch...${RESET}"
    mkdir -p "$STATE_DIR"
    if ! have_iptables; then
        echo -e "${YELLOW}⚠ iptables missing, using ufw only (weaker, no transparent proxy)${RESET}"
        if command -v ufw >/dev/null 2>&1; then
            ufw --force enable >/dev/null 2>&1 || true
            ufw default deny outgoing >/dev/null 2>&1 || true
            ufw default deny incoming >/dev/null 2>&1 || true
        fi
        return 0
    fi

    # save once (iptables-save covers filter + nat + mangle)
    if [[ ! -f "$IPT_BAK" ]]; then
        iptables-save > "$IPT_BAK" 2>/dev/null || true
    fi
    if command -v ip6tables-save >/dev/null 2>&1 && [[ ! -f "$IP6T_BAK" ]]; then
        ip6tables-save > "$IP6T_BAK" 2>/dev/null || true
    fi

    local tor_uid=$(get_tor_uid)
    if [[ -z "$tor_uid" ]]; then
        echo -e "${YELLOW}⚠ tor user not found, tor may fail to bootstrap (auto-rollback will trigger)${RESET}"
    fi

    # start clean so re-enable doesnt stack rules
    iptables -t nat -F
    iptables -t nat -X
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

    # transparent proxy: tcp -> tor transport, dns -> tor dnsport
    # loopback and tor itself are never redirected
    iptables -t nat -A OUTPUT -o lo -j RETURN
    if [[ -n "$tor_uid" ]]; then
        iptables -t nat -A OUTPUT -m owner --uid-owner "$tor_uid" -j RETURN
    fi
    iptables -t nat -A OUTPUT -p udp --dport 53 -j REDIRECT --to-ports $DNS_PORT
    iptables -t nat -A OUTPUT -p tcp --dport 53 -j REDIRECT --to-ports $DNS_PORT
    iptables -t nat -A OUTPUT -p tcp -j REDIRECT --to-ports $TRANS_PORT

    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # tor needs to reach guards on net
    if [[ -n "$tor_uid" ]]; then
        iptables -A OUTPUT -m owner --uid-owner "$tor_uid" -j ACCEPT
    else
        # fallback: allow tor ports to anywhere (better than nothing)
        iptables -A OUTPUT -p tcp --dport 9001 -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 9030 -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 443 -j ACCEPT
        iptables -A OUTPUT -p tcp --dport 80 -j ACCEPT
    fi

    # dhcp so we dont lose ip on laptop
    iptables -A OUTPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT
    iptables -A INPUT -p udp --sport 67:68 --dport 67:68 -j ACCEPT

    # redirected traffic loops back via lo (accepted above),
    # explicit allow for tor dns keeps the intent clear
    iptables -A OUTPUT -d 127.0.0.1 -p udp --dport $DNS_PORT -j ACCEPT
    iptables -A OUTPUT -d 127.0.0.1 -p tcp --dport $DNS_PORT -j ACCEPT

    disable_ipv6
}

disable_killswitch() {
    echo -e "${WHITE}🔹 Removing kill-switch...${RESET}"
    if have_iptables; then
        if [[ -f "$IPT_BAK" ]]; then
            iptables-restore < "$IPT_BAK" 2>/dev/null || {
                iptables -P INPUT ACCEPT
                iptables -P FORWARD ACCEPT
                iptables -P OUTPUT ACCEPT
                iptables -F
                iptables -X
                iptables -t nat -F
                iptables -t nat -X
            }
            rm -f "$IPT_BAK"
        else
            iptables -P INPUT ACCEPT
            iptables -P FORWARD ACCEPT
            iptables -P OUTPUT ACCEPT
            iptables -F
            iptables -X
            iptables -t nat -F
            iptables -t nat -X
        fi
        rm -f "$IP6T_BAK"
    fi
    restore_ipv6
    if command -v ufw >/dev/null 2>&1; then
        ufw default allow outgoing >/dev/null 2>&1 || true
        ufw default deny incoming >/dev/null 2>&1 || true
    fi
}

# save clear ip before we go dark, so leak test can compare
save_clear_ip() {
    mkdir -p "$STATE_DIR"
    local ip=$(curl --max-time 8 -s https://api.ipify.org 2>/dev/null || curl --max-time 8 -s https://ifconfig.me 2>/dev/null || echo "")
    if [[ -n "$ip" ]]; then
        echo "$ip" > "$CLEAR_IP_FILE"
    fi
}

get_tor_ip() {
    curl --max-time 15 --socks5 127.0.0.1:$TOR_PORT -s "https://check.torproject.org/api/ip" 2>/dev/null | grep -o '"IP":"[^"]*' | cut -d'"' -f4
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

# quick leak check: tor ip vs clear ip + dns + ipv6 + firewall
check_leaks() {
    echo -e "${BLUE}${BOLD}════ Leak check ════${RESET}"
    local fail=0

    local tor_ip=$(get_tor_ip)
    if [[ -z "$tor_ip" ]]; then
        echo -e "${RED}✖ no tor ip, tor socks down${RESET}"
        fail=1
    else
        echo -e "${GREEN}✓ tor ip: $tor_ip${RESET}"
    fi

    if [[ -f "$CLEAR_IP_FILE" ]]; then
        local clear_ip=$(cat "$CLEAR_IP_FILE")
        if [[ -n "$clear_ip" && -n "$tor_ip" ]]; then
            if [[ "$clear_ip" == "$tor_ip" ]]; then
                echo -e "${RED}✖ LEAK: tor ip == clear ip ($clear_ip)${RESET}"
                fail=1
            else
                echo -e "${GREEN}✓ tor ip differs from clear ip ($clear_ip)${RESET}"
            fi
        fi
    else
        echo -e "${YELLOW}⚠ no clear ip saved, skipping compare${RESET}"
    fi

    # dns must go through tor only
    local dns=$(grep -E '^\s*nameserver' "$RESOLV_FILE" 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
    echo -e "${WHITE}dns: $dns${RESET}"
    if [[ "$dns" == "127.0.0.1 " || "$dns" == "127.0.0.1" ]]; then
        echo -e "${GREEN}✓ dns via Tor (127.0.0.1)${RESET}"
    elif echo "$dns" | grep -Eq "192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.|127\.0\.0\.53"; then
        echo -e "${RED}✖ dns looks like local/isp, possible leak${RESET}"
        fail=1
    else
        echo -e "${RED}✖ dns bypasses tor ($dns)${RESET}"
        fail=1
    fi

    # resolution itself must work through tor
    if getent hosts check.torproject.org >/dev/null 2>&1; then
        echo -e "${GREEN}✓ dns resolves via Tor${RESET}"
    else
        echo -e "${RED}✖ dns resolution broken${RESET}"
        fail=1
    fi

    # ipv6 should be off
    if [[ -f /proc/net/if_inet6 ]] && [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null) != "1" ]]; then
        echo -e "${YELLOW}⚠ ipv6 is on, can bypass tor${RESET}"
    else
        echo -e "${GREEN}✓ ipv6 blocked/off${RESET}"
    fi

    # killswitch check
    if have_iptables; then
        if iptables -L OUTPUT -n 2>/dev/null | grep -q "DROP\|REJECT"; then
            echo -e "${GREEN}✓ firewall kill-switch active${RESET}"
        else
            echo -e "${YELLOW}⚠ kill-switch not active${RESET}"
        fi
        # proof: direct (non-proxychained) traffic must exit via tor ip
        local direct_ip=$(curl --max-time 15 -s https://api.ipify.org 2>/dev/null || echo "")
        if [[ -z "$direct_ip" ]]; then
            echo -e "${YELLOW}⚠ direct connection failed (transparent proxy not redirecting?)${RESET}"
        elif [[ "$direct_ip" == "$tor_ip" ]]; then
            echo -e "${GREEN}✓ transparent proxy working (direct net exits via Tor)${RESET}"
        else
            echo -e "${RED}✖ LEAK: direct net exits via $direct_ip (not Tor)${RESET}"
            fail=1
        fi

        # proof: plaintext dns to the outside must be blocked
        if ! command -v timeout >/dev/null 2>&1; then
            echo -e "${YELLOW}⚠ timeout cmd missing, skipping direct-dns proof${RESET}"
        elif timeout 5 bash -c '</dev/tcp/1.1.1.1/53' 2>/dev/null; then
            echo -e "${RED}✖ LEAK: direct dns reachable (bypasses Tor)${RESET}"
            fail=1
        else
            echo -e "${GREEN}✓ direct dns blocked (must use Tor)${RESET}"
        fi
    fi

    # ipv6 external test, should fail when blocked
    if curl --max-time 5 -s -6 https://api6.ipify.org >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠ ipv6 net reachable, may bypass tor${RESET}"
    else
        echo -e "${GREEN}✓ no ipv6 leak${RESET}"
    fi

    if [[ $fail -eq 0 ]]; then
        echo -e "${GREEN}✓ no obvious leaks${RESET}"
    else
        echo -e "${RED}✖ leaks found, check above${RESET}"
    fi
    return $fail
}

# cut everything now, for emergencies
panic_mode() {
    echo -e "${RED}${BOLD}!! PANIC: cutting network !!${RESET}"
    if have_iptables; then
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT DROP
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
    fi
    if command -v ip6tables >/dev/null 2>&1; then
        ip6tables -P INPUT DROP 2>/dev/null || true
        ip6tables -P FORWARD DROP 2>/dev/null || true
        ip6tables -P OUTPUT DROP 2>/dev/null || true
    fi
    systemctl stop tor 2>/dev/null || service tor stop 2>/dev/null || true
    echo -e "${YELLOW}net cut. run disable (option 2) to restore.${RESET}"
    echo "panic $(date)" >> "$LOG_FILE" 2>/dev/null || true
}

# new circuit / new ip without full re-setup
new_identity() {
    echo -e "${WHITE}🔹 Getting new identity...${RESET}"
    local old_ip=$(get_tor_ip)
    [[ -n "$old_ip" ]] && echo -e "${WHITE}old ip: $old_ip${RESET}"

    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl restart tor 2>/dev/null || service tor restart 2>/dev/null || true
    else
        service tor restart 2>/dev/null || true
    fi
    echo -e "${WHITE}waiting for tor...${RESET}"
    sleep 7

    local new_ip=$(get_tor_ip)
    if [[ -z "$new_ip" ]]; then
        echo -e "${RED}✖ couldnt get new ip, tor may still be starting${RESET}"
        return 1
    fi
    echo -e "${GREEN}✓ new ip: $new_ip${RESET}"
    if [[ "$old_ip" == "$new_ip" ]]; then
        echo -e "${YELLOW}⚠ same as before, try again in a bit${RESET}"
    fi
}

# Enable anonymity
enable_anon() {
    if ! check_internet; then
        echo -e "${RED}✖ No internet connection${RESET}"
        return 1
    fi

    # dont run twice by mistake
    if [[ -f "$STATE_FILE" ]] && grep -q "enabled" "$STATE_FILE" 2>/dev/null; then
        echo -e "${YELLOW}⚠ Anonymity already enabled${RESET}"
    fi

    echo -e "${BLUE}${BOLD}🔹 Enabling anonymity mode...${RESET}"

    install_packages || {
        echo -e "${RED}✖ Setup aborted, packages missing${RESET}"
        return 1
    }

    save_clear_ip
    backup_once "$RESOLV_FILE" "$RESOLV_BAK"
    unlock_dns
    lock_dns

    setup_tor
    setup_proxychains

    # firewall kill-switch, tor socks is local only so no need to open ports
    enable_killswitch
    if command -v ufw >/dev/null 2>&1; then
        ufw --force enable >/dev/null 2>&1 || true
    fi

    echo "enabled $(date)" > "$STATE_FILE"

    if check_tor; then
        echo -e "${GREEN}✓ Anonymity enabled${RESET}"
        show_status
        check_leaks || true
        echo -e "${YELLOW}tip: tcp/dns now goes via tor transparently, just use apps normally (udp stays blocked)${RESET}"
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

    unlock_dns
    [[ -f "$RESOLV_BAK" ]] && mv "$RESOLV_BAK" "$RESOLV_FILE" 2>/dev/null
    [[ -f "$TOR_BAK" ]] && mv "$TOR_BAK" "$TOR_CONF" 2>/dev/null
    [[ -f "$PROXY_BAK" ]] && mv "$PROXY_BAK" "$PROXYCHAINS_CONF" 2>/dev/null

    disable_killswitch
    rm -f "$STATE_FILE" "$CLEAR_IP_FILE"

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
        echo -e "${YELLOW}⚠ Check network settings, you may need to reboot if panic was used${RESET}"
    fi
}

# Show status
show_status() {
    echo -e "${BLUE}${BOLD}════════════ System Status ════════════${RESET}"
    printf "${WHITE}%-20s: %s${RESET}\n" "Version" "$VERSION"
    printf "${WHITE}%-20s: %s${RESET}\n" "Interface" "$INTERFACE"

    if [[ -f "$STATE_FILE" ]]; then
        printf "${WHITE}%-20s: %s${RESET}\n" "Mode" "$(cat $STATE_FILE)"
    else
        printf "${WHITE}%-20s: %s${RESET}\n" "Mode" "normal"
    fi

    local tor_status="inactive"
    if command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]; then
        systemctl is-active --quiet tor && tor_status="active"
    else
        pgrep -x tor >/dev/null 2>&1 && tor_status="active"
    fi
    printf "${WHITE}%-20s: %s${RESET}\n" "Tor Service" "$tor_status"

    if [[ "$tor_status" == "active" ]]; then
        local tor_ip=$(get_tor_ip)
        [[ -n "$tor_ip" ]] && printf "${WHITE}%-20s: %s${RESET}\n" "Tor IP" "$tor_ip"
    fi

    printf "${WHITE}%-20s: %s${RESET}\n" "DNS Servers" "$(grep nameserver "$RESOLV_FILE" 2>/dev/null | cut -d' ' -f2 | tr '\n' ' ')"
    if [[ $(cat /proc/sys/net/ipv6/conf/all/disable_ipv6 2>/dev/null) == "1" ]]; then
        printf "${WHITE}%-20s: %s${RESET}\n" "IPv6" "disabled"
    else
        printf "${WHITE}%-20s: %s${RESET}\n" "IPv6" "on"
    fi
    local trans="off"
    if have_iptables && iptables -t nat -L OUTPUT -n 2>/dev/null | grep -q "REDIRECT.*$TRANS_PORT"; then
        trans="on"
    fi
    printf "${WHITE}%-20s: %s${RESET}\n" "Transparent" "$trans"
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
        echo -e "[4] Leak check"
        echo -e "[5] New identity"
        echo -e "[6] Panic (cut net)"
        echo -e "[7] Exit${RESET}"
        echo -e "${BLUE}${BOLD}════════════════════════════════════${RESET}"

        read -rp "Select option [1-7]: " choice
        case $choice in
            1) enable_anon ;;
            2) disable_anon ;;
            3) show_status ;;
            4) check_leaks ;;
            5) new_identity ;;
            6) panic_mode ;;
            7) exit 0 ;;
            *) echo -e "${RED}✖ Invalid option${RESET}" ;;
        esac
        read -rp "Press Enter to continue..." _
    done
}

show_help() {
    echo "Usage: sudo ./Anonyx.sh [--enable|--disable|--status|--leaktest|--newid|--panic|--help]"
    echo "  no args      open menu"
    echo "  --enable     enable anonymity + killswitch"
    echo "  --disable    restore normal settings"
    echo "  --status     show tor + dns status"
    echo "  --leaktest   check for ip/dns/ipv6 leaks"
    echo "  --newid      restart tor for new ip"
    echo "  --panic      cut all net immediately"
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
    --leaktest|-l) check_leaks; exit $? ;;
    --newid|-n) new_identity; exit $? ;;
    --panic) panic_mode; exit 0 ;;
    --help|-h) show_help; exit 0 ;;
    --version|-v) echo "Anonyx $VERSION"; exit 0 ;;
    "") main_menu ;;
    *) echo -e "${RED}✖ Unknown option: $1${RESET}"; show_help; exit 1 ;;
esac
