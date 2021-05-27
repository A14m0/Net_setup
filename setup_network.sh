#!/bin/bash

ETH_INTERFACE="enp4s0"
WIRELESS_INTERFACE="wlp2s0"

# sets up the NAT for the new network
function setup_nat(){
    systemctl start named

    sysctl net.ipv4.ip_forward=1
    sysctl net.ipv6.conf.default.forwarding=1
    sysctl net.ipv6.conf.all.forwarding=1

    iptables -t nat -A POSTROUTING -o $ETH_INTERFACE -j MASQUERADE
    iptables -A FORWARD -i $ETH_INTERFACE -o $WIRELESS_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -i $WIRELESS_INTERFACE -o $ETH_INTERFACE -j ACCEPT

}

# start the access point
function start_ap(){
    nmcli radio wifi off
    rfkill unblock wlan

    ip link set down dev $WIRELESS_INTERFACE
    ifconfig $WIRELESS_INTERFACE 133.7.0.1/24 up
    sleep 1

    systemctl start hostapd.service

    setup_nat

    echo "[i] Sleeping to allow AP to start..."
    sleep 5

    systemctl start dhcpd4.service

    echo "Ur n37w0rk is s37up"
    #IFS="="

    ap=$(cat /etc/hostapd/hostapd.conf | grep "ssid=" | grep -v "#" | head -n 1 | sed 's/.*ssid=//')
    pw=$(cat /etc/hostapd/hostapd.conf | grep "wpa_passphrase=" | grep -v "#" | head -n 1 | sed 's/.*wpa_passphrase=//')
    echo "SS1D is: \"${ap}\""
    echo "P4ssW0rd is: \"${pw}\""

    echo "[ ] Starting HostAPD..."
    systemctl status hostapd.service

    echo "[ ] Starting DHCPD4..."
    systemctl status dhcpd4.service

    echo "[ ] Starting NameD..."
    systemctl status named
}

function stop_ap(){
    nmcli radio wifi on

    systemctl stop named
    systemctl stop dhcpd4.service
    systemctl stop hostapd.service

    echo "R3st0r3d"
}

function usage(){
    echo "Usage: Program (--start|--stop)"
}

function main(){
    if [[ $EUID -ne 0 ]]; then
        echo "101 ur n0t r00t"
        exit 1
    fi

    if [[ $# -lt 1 ]]; then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]]
    do
        key="$1"
        case $key in
            -s|--start)
                start_ap
                shift
                ;;
            -r|--stop)
                stop_ap
                shift
                ;;
            *)
                usage
                shift
                ;;
        esac
    done
}

main $@
