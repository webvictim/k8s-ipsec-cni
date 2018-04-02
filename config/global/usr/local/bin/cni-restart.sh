#!/bin/bash
# load the CNI IP from file
source /usr/local/bin/cni-ip

# add iptables rules at the top of the FORWARD chain to allow all traffic on the CNI interface
iptables -I FORWARD 1 -o cni0 -j ACCEPT
iptables -I FORWARD 1 -i cni0 -j ACCEPT

# add cni0 bridge - this is done automatically by the CNI plugin if the bridge doesn't exist, but strongswan needs
# to be restarted after the bridge is added so we add it manually to make the startup cleaner
brctl addbr cni0
ip addr add $CNI_IP/24 dev cni0
ip link set dev cni0 up

# exit with success to avoid blocking anything else
exit 0