#!/bin/bash

function start_ap(){
    nmcli radio wifi off
    rfkill unblock wlan

    ip link set down dev wlp3s0
    ifconfig wlp0s20f0u3 133.7.0.1/24 up
    sleep 1

    systemctl start hostapd.service

    echo "[i] Sleeping to allow AP to start..."
    sleep 5

    systemctl start dhcpd4.service

    echo "Ur n37w0rk is s37up"
    IFS="="

    str=$(cat /etc/hostapd/hostapd.conf | grep wpa_passphrase | grep -v "#")
    read -ra ADDR <<< "$str"
    echo "P4ssW0rd is: \"${ADDR[1]}\""

    systemctl status hostapd.service
    systemctl status dhcpd4.service
}

function stop_ap(){
    nmcli radio wifi on

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
