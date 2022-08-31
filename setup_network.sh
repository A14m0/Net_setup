#!/bin/bash

ETH_INTERFACE="eno1"
WIRELESS_INTERFACE="wlp2s0"

# sets up the NAT for the new network
function setup_nat(){
    systemctl start named

    sysctl net.ipv4.ip_forward=1
    sysctl net.ipv6.conf.default.forwarding=1
    sysctl net.ipv6.conf.all.forwarding=1

    echo "[ ] Backing up IPTable rules..."
    iptables-save > /tmp/tables_backup.bak

    echo "[ ] Flushing IPTable rules..."
    iptables -F
    iptables -t nat -F

    echo "[ ] Setting up forwarding..."
    # for the NAT table,
    #   PRE-ROUTING: Packets when the DESTINATION address needs to be changed
    #   POST-ROUTING: Packets when the SOURCE address needs to be changed
    #   OUTPUT: Packets originating from the firewall

    # PACKET PATH: NAT_PRE-ROUTING -> FORWARD chain -> NAT_POST-ROUTING -> out
    iptables -A PREROUTING -i $ETH_INTERFACE -j ACCEPT
    iptables -t nat -A POSTROUTING -s 192.168.91.0/24 -j MASQUERADE
    # append to the FORWARD chain, packets going into ETH_INF and out WIRELESS_INF, if the packet is part of a related or established connection, allow them
    iptables -A FORWARD -i $ETH_INTERFACE -o $WIRELESS_INTERFACE -m state --state RELATED,ESTABLISHED -j ACCEPT
    # append to the FORWARD chain, packets going into WIRELESS_INF and out ETH_INF, allow them
    iptables -A FORWARD -i $WIRELESS_INTERFACE -o $ETH_INTERFACE -j ACCEPT

}

# start the access point
function start_ap(){
    nmcli radio wifi off
    rfkill unblock wlan

    ip link set down dev $WIRELESS_INTERFACE
    ifconfig $WIRELESS_INTERFACE 192.168.91.1/24 up
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

    iptables-restore < /tmp/tables_backup.bak
    rm -f /tmp/tables_backup.bak

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
