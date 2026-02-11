
#!/bin/bash

# ======================================================
#   Advanced Network Protocol Tester by A-battousai
#   GitHub: https://github.com/A-battousai
# ======================================================

prepare_env() {
    echo -e "\n--- [Step 1/2] Checking Prerequisites ---"
    PACKAGES=("iperf3" "nc" "python3" "ping" "curl")
    MISSING_PKGS=()
    for pkg in "${PACKAGES[@]}"; do
        if ! command -v $pkg &>/dev/null; then MISSING_PKGS+=($pkg); fi
    done

    if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
        echo "Installing requirements (Please wait)..."
        sudo apt-get update -qq
        sudo apt-get install -y -qq iperf3 netcat-openbsd python3 iputils-ping curl
    else
        echo "System is ready."
    fi
}

clear
echo -e "\e[1;36m======================================================\e[0m"
echo -e "\e[1;33m       Network Tester by A-battousai                  \e[0m"
echo -e "\e[1;36m======================================================\e[0m"

prepare_env

echo -e "\nWhich side is this server?"
echo "1) Side A (Starter/Client - Runs the test from IR)"
echo "2) Side B (Listener/Server - Foreign Server)"
read -p "Select (1/2): " SIDE

if [ "$SIDE" == "2" ]; then
    echo -e "\n--- Side B: Listening Mode ---"
    SERVER_IP=$(curl -s https://api.ipify.org || hostname -I | awk '{print $1}')
    echo -e "\e[1;32m>>> YOUR SERVER IP: $SERVER_IP <<<\e[0m"
    echo "Copy this IP and use it on Side A."
    pkill iperf3 2>/dev/null
    pkill nc 2>/dev/null
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
    # اصلاح خودکار ورودی: حذف کلمه IP، فضای خالی و دو نقطه
    B_IP=$(echo $RAW_IP | sed 's/[iIpP: ]//g')
    
    echo -e "Testing target: \e[1;34m$B_IP\e[0m"
    echo -e "\n--- Starting Connectivity Tests ---\n"

    check_tcp_udp() {
        local PORT=$1
        local LABEL=$2
        nc -zv -w 3 $B_IP $PORT &>/dev/null && T_RES="\e[32mTCP-OK\e[0m" || T_RES="\e[31mTCP-NO\e[0m"
        nc -zvu -w 3 $B_IP $PORT &>/dev/null && U_RES="\e[32mUDP-OK\e[0m" || U_RES="\e[31mUDP-NO\e[0m"
        echo -e "[$LABEL Port $PORT]: $T_RES | $U_RES"
    }

    check_tcp_udp 443 "Web/TLS"
    check_tcp_udp 9000 "Custom"
    check_tcp_udp 5201 "iPerf3"

    echo -e "\n--- L3/Tunneling Analysis ---"
    PING_DATA=$(ping -c 3 -W 2 $B_IP | tail -1 | awk -F '/' '{print $5}')
    if [ ! -z "$PING_DATA" ]; then
        echo -e "[Basic Ping]: \e[32mPASS (Latency: ${PING_DATA}ms)\e[0m"
        ping -c 2 -s 1450 -W 2 $B_IP &>/dev/null && MTU_RES="\e[32mSUPPORTED\e[0m" || MTU_RES="\e[31mFAILED\e[0m"
        echo -e "[Large Packets]: $MTU_RES"
    else
        echo -e "[ICMP]: \e[31mFAILED\e[0m"
    fi

    echo -e "\n--- Analyzing Quality (2MB UDP Stress Test) ---"
    iperf3 -c $B_IP -u -b 2M -t 5 --json > result.json 2>/dev/null
    
    python3 -c "
import json
try:
    with open('result.json') as f:
        data = json.load(f)
        lost = data['end']['sum']['lost_percent']
        jitter = data['end']['sum']['jitter_ms']
        print(f'>> Quality Results: Loss={lost:.1f}% | Jitter={jitter:.1f}ms')
        
        print('\n\033[1;36m================= RECOMMENDATIONS =================\033[0m')
        print(f'1. L3 Tunnels (GRE/IPIP): \033[92mEXCELLENT\033[0m (Ping is stable)')
        
        print('2. gRPC/Websocket (TCP): ', end='')
        if lost < 2: print('\033[92mRecommended (High Speed)\033[0m')
        else: print('\033[93mPossible (Expect some delay)\033[0m')

        print('3. KCP/QUIC (UDP): ', end='')
        if lost > 3: print('\033[92mBEST CHOICE (Fixes packet loss)\033[0m')
        else: print('\033[94mOptional (Not required)\033[0m')
        print('\033[1;36m===================================================\033[0m')

        print('\n--- FINAL VERDICT ---')
        if lost == 0: print('\033[92m[PERFECT]: Use GRE Tunnel + Any Protocol.\033[0m')
        elif lost < 4: print('\033[93m[STABLE]: Use Reality (gRPC) or Shadowsocks.\033[0m')
        else: print('\033[91m[POOR]: High Loss! Best fix is KCP or Paqet.\033[0m')
except:
    print('\n\033[91m[!] Quality test failed. iPerf3 port is blocked.\033[0m')
"
    rm -f result.json
    echo -e "\n--- Test Finished by A-battousai ---"
fi
