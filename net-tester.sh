#!/bin/bash

# ======================================================
#   Advanced Network Protocol Tester by A-battousai
# ======================================================

# Function to fix colors in echo
echo_c() {
    echo -e "$1"
}

prepare_env() {
    echo_c "\n\e[1;36m[1/2] System Check...\e[0m"
    PACKAGES=("iperf3" "nc" "python3" "ping" "curl")
    MISSING_PKGS=()
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v $pkg &>/dev/null; then MISSING_PKGS+=($pkg); fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        sudo apt-get update -qq && sudo apt-get install -y -qq iperf3 netcat-openbsd python3 iputils-ping curl
    else
        echo_c "\e[32mPrerequisites met.\e[0m"
    fi
}

clear
echo_c "\e[1;36m======================================================\e[0m"
echo_c "\e[1;33m           Advanced Network Diagnostic Tool           \e[0m"
echo_c "\e[1;36m======================================================\e[0m"

prepare_env

echo_c "\nSelect Operation Mode:"
echo "1) Side A (Initiator/Client - IR)"
echo "2) Side B (Receiver/Server - Foreign)"
read -p "Selection: " SIDE

if [ "$SIDE" == "2" ]; then
    SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
    echo_c "\n\e[1;32m>>> SERVER IP: $SERVER_IP <<<\e[0m"
    pkill iperf3 2>/dev/null
    pkill nc 2>/dev/null
    iperf3 -s -D > /dev/null 2>&1
    nc -lk -p 9000 > /dev/null 2>&1 &
    nc -lku -p 9000 > /dev/null 2>&1 &
    echo_c "\e[32mStatus: Side B is listening on ports 9000 & 5201...\e[0m"
    while true; do sleep 60; done

elif [ "$SIDE" == "1" ]; then
    read -p "Enter Side B IP: " RAW_IP
    B_IP=$(echo "$RAW_IP" | grep -oE '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
    
    echo_c "\e[1;34mTarget: $B_IP\e[0m\n"

    check_port() {
        local PORT=$1
        local NAME=$2
        nc -zv -w 3 $B_IP $PORT &>/dev/null && T_RES="\e[1;32mOK\e[0m" || T_RES="\e[1;31mBLOCKED\e[0m"
        nc -zvu -w 3 $B_IP $PORT &>/dev/null && U_RES="\e[1;32mOK\e[0m" || U_RES="\e[1;31mBLOCKED\e[0m"
        printf "%-25s TCP: %b | UDP: %b\n" "[$NAME Port $PORT]:" "$T_RES" "$U_RES"
    }

    check_port 443 "HTTPS/TLS"
    check_port 9000 "Custom"
    check_port 5201 "iPerf3"

    echo_c "\n\e[1;36m--- Latency & MTU Analysis ---\e[0m"
    PING_RES=$(ping -c 3 -W 2 $B_IP | tail -1 | awk -F '/' '{print $5}')
    if [ ! -z "$PING_RES" ]; then
        echo_c "Latency: ${PING_RES}ms"
        ping -c 2 -s 1450 -W 2 $B_IP &>/dev/null && echo_c "MTU 1450: \e[32mSUCCESS\e[0m" || echo_c "MTU 1450: \e[31mFAILED\e[0m"
    else
        echo_c "Ping: \e[31mFAILED\e[0m"
    fi

    echo_c "\n\e[1;36m--- Stress Test (2MB UDP Flow) ---\e[0m"
    iperf3 -c $B_IP -u -b 2M -t 5 --json > res.json 2>/dev/null
    
    python3 -c "
import json
try:
    with open('res.json') as f:
        data = json.load(f)
        lost = data['end']['sum']['lost_percent']
        jitter = data['end']['sum']['jitter_ms']
        print(f'>> Quality: Loss={lost:.1f}% | Jitter={jitter:.2f}ms')
        print('\n\033[1;33m[ RECOMMENDATIONS ]\033[0m')
        print(f'• L3 Tunnels (GRE/IPIP): \033[32mEXCELLENT\033[0m')
        print(f'• TCP (TLS/Reality):    ' + ('\033[32mHIGHLY RECOMMENDED\033[0m' if lost < 2 else '\033[33mSTABLE\033[0m'))
        print(f'• UDP (Hysteria/QUIC):  ' + ('\033[34mOPTIONAL (Link is clean)\033[0m' if lost < 3 else '\033[32mBEST CHOICE (Fixes loss)\033[0m'))
        print('\n--- FINAL VERDICT ---')
        if lost < 1: print('\033[1;32m[PERFECT] Link is transparent. Use any protocol.\033[0m')
        else: print('\033[1;33m[STABLE] Minor loss detected. KCP/Hysteria recommended.\033[0m')
except:
    print('\033[31mTest incomplete. Check Side B status.\033[0m')
"
    rm -f res.json
    echo_c "\n\e[1;36m--- Diagnostics Complete ---\e[0m"
fi
