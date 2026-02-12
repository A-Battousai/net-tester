#!/bin/bash

# ======================================================
#   Advanced Network Tester by A-battousai
#   GitHub: https://github.com/A-battousai
#   Final Stable Version (Green UI & Jitter Fixed)
# ======================================================

prepare_env() {
    echo -e "\n--- [Step 1/2] Checking Prerequisites ---"
    PACKAGES=("iperf3" "nc" "python3" "ping" "curl")
    MISSING_PKGS=()
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v $pkg &>/dev/null; then MISSING_PKGS+=($pkg); fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo "Installing requirements..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq iperf3 netcat-openbsd python3 iputils-ping curl
    fi
}

clear
echo -e "\e[1;36m======================================================\e[0m"
echo -e "\e[1;33m      Advanced Network Tester by A-battousai          \e[0m"
echo -e "\e[1;36m======================================================\e[0m"

prepare_env

echo -e "\nWhich side is this server?"
echo "1) Side A (Starter/Client - Iran)"
echo "2) Side B (Listener/Server - Foreign)"
read -p "Select (1/2): " SIDE

if [ "$SIDE" == "2" ]; then
    echo -e "\n--- Side B: Listening Mode ---"
    SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
    echo -e "\e[1;32m>>> YOUR SERVER IP: $SERVER_IP <<<\e[0m"
    pkill iperf3 2>/dev/null; pkill nc 2>/dev/null
    sleep 1
    iperf3 -s -D > /dev/null 2>&1
    nc -lk -p 9000 > /dev/null 2>&1 &
    nc -lku -p 9000 > /dev/null 2>&1 &
    nc -lk -p 5201 > /dev/null 2>&1 &
    echo -e "\e[1;32mStatus: Server is Ready and Waiting...\e[0m"
    while true; do sleep 60; done

elif [ "$SIDE" == "1" ]; then
    echo -e "\n--- Side A: Tester Mode ---"
    read -p "Enter IP of Side B: " RAW_IP
    B_IP=$(echo $RAW_IP | sed 's/[iIpP: ]//g')
    
    echo -e "\n\e[1;35m[1/4] Global Internet (Google)\e[0m"
    G_RECV=$(ping -4 -c 10 -i 0.2 -p 1234 -W 1 8.8.8.8 | grep 'received' | awk -F',' '{print $2}' | awk '{print $1}')
    G_RECV=${G_RECV:-0}
    echo -e "      Access: \e[1;32m$G_RECV/10 Packets Received\e[0m"

    echo -e "\n\e[1;35m[2/4] Port Analysis (L4)\e[0m"
    check_tcp_udp() {
        local PORT=$1
        local LABEL=$2
        nc -zv -w 3 $B_IP $PORT &>/dev/null && T_RES="\e[32mOK\e[0m" || T_RES="\e[31mNO\e[0m"
        nc -zvu -w 3 $B_IP $PORT &>/dev/null && U_RES="\e[32mOK\e[0m" || U_RES="\e[31mNO\e[0m"
        echo -e "      $LABEL (Port $PORT) -> TCP: $T_RES | UDP: $U_RES"
    }
    check_tcp_udp 443 "Web/TLS"
    check_tcp_udp 9000 "Custom "
    check_tcp_udp 5201 "iPerf3 "

    echo -e "\n\e[1;35m[3/4] Stability & MTU (L3)\e[0m"
    PING_RAW=$(ping -4 -c 10 -i 0.2 -W 1 $B_IP)
    RECV=$(echo "$PING_RAW" | grep 'received' | awk -F',' '{print $2}' | awk '{print $1}')
    RECV=${RECV:-0}
    LATENCY=$(echo "$PING_RAW" | tail -1 | awk -F '/' '{print $5}')
    
    # رنگ سبز برای پایداری عالی
    if [ "$RECV" -eq 10 ]; then 
        P_COLOR="\e[1;32m"; P_ICON="\e[32m[✔]\e[0m"
    elif [ "$RECV" -ge 8 ]; then 
        P_COLOR="\e[1;33m"; P_ICON="\e[33m[✔]\e[0m"
    else 
        P_COLOR="\e[1;31m"; P_ICON="\e[31m[✘]\e[0m"
    fi
    echo -e "      $P_ICON Stability : ${P_COLOR}$RECV/10 Packets\e[0m | Latency: \e[1;33m${LATENCY}ms\e[0m"

    # رنگ سبز برای MTU موفق
    if ping -4 -c 5 -s 1450 -W 1 $B_IP &>/dev/null; then
        MTU_STATUS="SUPPORTED"; MTU_ICON="\e[32m[✔]\e[0m"; MTU_COLOR="\e[1;32m"
    else
        MTU_STATUS="FAILED"; MTU_ICON="\e[31m[✘]\e[0m"; MTU_COLOR="\e[1;31m"
    fi
    echo -e "      $MTU_ICON MTU (1450): ${MTU_COLOR}$MTU_STATUS\e[0m"

    echo -e "\n\e[1;35m[4/4] Quality Stress Test (iPerf3)\e[0m"
    iperf3 -c $B_IP -u -b 10M -t 7 --json > result.json 2>/dev/null
    
    python3 -c "
import json
try:
    ping_val = $RECV
    mtu_val = '$MTU_STATUS'
    with open('result.json') as f:
        data = json.load(f)
        lost = data['end']['sum']['lost_percent']
        jitter = data['end']['sum']['jitter_ms']
        
    s_icon = '\033[1;32m[✔]\033[0m' if lost < 1 else '\033[1;31m[✘]\033[0m'
    print(f'      {s_icon} Stress Result: Loss={lost:.2f}% | Jitter={jitter:.1f}ms')
    print('\n\033[1;36m================= RECOMMENDATIONS =================\033[0m')
    
    if ping_val < 8 or mtu_val == 'FAILED':
        print('\033[41m\033[97m   STATUS: HIGHLY FILTERED / SHADOW BANNED   \033[0m')
    else:
        print(' 1. TCP (gRPC/WS/TLS): ', end='')
        if lost > 8: print('\033[91mNOT RECOMMENDED\033[0m')
        else: print('\033[92mHighly Recommended\033[0m')

        print(' 2. Multi-Path (KCP/Hysteria): ', end='')
        if lost > 2: print('\033[92mRecommended\033[0m')
        else: print('\033[94mOptional\033[0m')
    print('\033[1;36m===================================================\033[0m')
except:
    print('      \033[31m[✘] Stress test blocked by Firewall.\033[0m')
"
    rm -f result.json
    echo -e "\n\e[1;36m--- Test Finished by A-battousai ---\e[0m"
fi
