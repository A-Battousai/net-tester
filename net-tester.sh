#!/bin/bash

# ======================================================
#   Advanced Network Protocol Tester Pro
#   Enhanced & Debugged Version
# ======================================================

# --- Styling ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'

prepare_env() {
    echo -e "\n${CYAN}[1/2] System Check...${NC}"
    PACKAGES=("iperf3" "nc" "python3" "ping" "curl")
    MISSING_PKGS=()
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v "$pkg" &>/dev/null; then MISSING_PKGS+=("$pkg"); fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo -e "${YELLOW}Installing: ${MISSING_PKGS[*]}${NC}"
        sudo apt-get update -qq && sudo apt-get install -y -qq iperf3 netcat-openbsd python3 iputils-ping curl
    else
        echo -e "${GREEN}Prerequisites met.${NC}"
    fi
}

cleanup() {
    pkill -f "iperf3"
    pkill -f "nc -lk"
    echo -e "\n${YELLOW}Cleaned up background processes.${NC}"
}

clear
echo -e "${CYAN}======================================================${NC}"
echo -e "${YELLOW}           Advanced Network Diagnostic Tool           ${NC}"
echo -e "${CYAN}======================================================${NC}"

prepare_env

echo -e "\n${CYAN}Select Operation Mode:${NC}"
echo -e "1) ${GREEN}Side A${NC} (Initiator/Client)"
echo -e "2) ${GREEN}Side B${NC} (Receiver/Server)"
read -rp "Selection: " SIDE

if [ "$SIDE" == "2" ]; then
    trap cleanup EXIT
    echo -e "\n${CYAN}--- Side B: Listening Mode ---${NC}"
    SERVER_IP=$(curl -s --max-time 5 https://api.ipify.org || hostname -I | awk '{print $1}')
    echo -e "${GREEN}>>> TARGET IP: $SERVER_IP <<<$NC"
    
    # Kill old instances
    pkill iperf3 2>/dev/null
    pkill nc 2>/dev/null
    
    # Start Listeners
    iperf3 -s -D > /dev/null 2>&1
    nc -lk -p 9000 > /dev/null 2>&1 &
    nc -lku -p 9000 > /dev/null 2>&1 &
    
    echo -e "${GREEN}Status: Ready. Monitoring Ports 5201 (iPerf) and 9000 (TCP/UDP)${NC}"
    echo "Keep this window open. Press [CTRL+C] to stop."
    while true; do sleep 1; done

elif [ "$SIDE" == "1" ]; then
    echo -e "\n${CYAN}--- Side A: Tester Mode ---${NC}"
    read -rp "Enter Side B IP: " RAW_IP
    # Strip common prefixes and spaces
    B_IP=$(echo "$RAW_IP" | sed -E 's/^(IP|ip)[: ]*//g' | tr -d ' ')
    
    echo -e "Target: ${CYAN}$B_IP${NC}\n"

    check_tcp_udp() {
        local PORT=$1
        local LABEL=$2
        # TCP Check
        nc -zv -w 3 "$B_IP" "$PORT" &>/dev/null && T_RES="${GREEN}OK${NC}" || T_RES="${RED}BLOCKED${NC}"
        # UDP Check (using iperf/nc timeout logic)
        echo "test" | nc -u -w 2 "$B_IP" "$PORT" &>/dev/null && U_RES="${GREEN}OK${NC}" || U_RES="${RED}NO-REPLY${NC}"
        
        printf "[%-12s Port %s]: TCP: %-15s | UDP: %s\n" "$LABEL" "$PORT" "$T_RES" "$U_RES"
    }

    check_tcp_udp 443 "HTTPS/TLS"
    check_tcp_udp 9000 "Custom"
    check_tcp_udp 5201 "iPerf3"

    echo -e "\n${CYAN}--- Latency & MTU Analysis ---${NC}"
    PING_DATA=$(ping -c 4 -W 2 "$B_IP" | tail -1 | awk -F '/' '{print $5}')
    if [ -n "$PING_DATA" ]; then
        echo -e "Latency: ${GREEN}${PING_DATA}ms${NC}"
        ping -c 2 -s 1450 -W 2 "$B_IP" &>/dev/null && echo -e "MTU 1450: ${GREEN}SUCCESS${NC}" || echo -e "MTU 1450: ${RED}FRAGMENTED${NC}"
    else
        echo -e "ICMP: ${RED}UNREACHABLE${NC}"
    fi

    echo -e "\n${CYAN}--- Stress Test (2MB UDP Flow) ---${NC}"
    iperf3 -c "$B_IP" -u -b 2M -t 5 --json > result.json 2>/dev/null
    
    python3 -c "
import json, sys
try:
    with open('result.json') as f:
        data = json.load(f)
    
    # Extract data safely
    end = data.get('end', {})
    sum_data = end.get('sum') or end.get('sum_received')
    
    if not sum_data:
        raise ValueError('No data')

    lost = sum_data.get('lost_percent', 0)
    jitter = sum_data.get('jitter_ms', 0)
    
    print(f'>> Quality: Loss={lost:.1f}% | Jitter={jitter:.2f}ms')
    
    print('\n\033[1;36m[ RECOMMENDATIONS ]\033[0m')
    
    # 1. Tunneling
    status = '\033[92mEXCELLENT\033[0m' if lost < 1 else '\033[93mDEGRADED\033[0m'
    print(f'• L3 Tunnels (GRE/IPIP): {status}')
    
    # 2. TCP Protocols
    if lost < 2:
        print('• TCP (TLS/Reality):    \033[92mHIGHLY RECOMMENDED\033[0m')
    else:
        print('• TCP (TLS/Reality):    \033[91mNOT IDEAL (High Retransmission)\033[0m')

    # 3. UDP Protocols
    if lost > 3:
        print('• UDP (Hysteria/QUIC):  \033[92mREQUIRED (Best for Loss)\033[0m')
    else:
        print('• UDP (Hysteria/QUIC):  \033[94mOPTIONAL (Link is clean)\033[0m')

    print('\n\033[1;36m--- FINAL VERDICT ---\033[0m')
    if lost == 0:   print('\033[92m[PERFECT] Link is transparent. Use any protocol.\033[0m')
    elif lost < 4: print('\033[93m[STABLE] Some congestion. Use Reality or Shadowsocks.\033[0m')
    else:          print('\033[91m[UNSTABLE] Heavy filtering. Use Hysteria2 or Tuic5.\033[0m')

except Exception as e:
    print('\n\033[91m[!] Test failed: Port 5201 is likely blocked or unreachable.\033[0m')
"
    rm -f result.json
    echo -e "\n${CYAN}--- Diagnostics Complete ---${NC}"
fi
