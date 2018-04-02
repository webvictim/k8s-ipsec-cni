#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# debugging
echo "TOKEN: $TOKEN"
echo "MASTER_IP: $MASTER_IP"
echo "HOSTNAME: $HOSTNAME"
echo "CNI_IP: $CNI_IP"

# we do a reset first to leave any existing cluster - this also allows us to rerun the vagrant provisioner if needed
kubeadm reset
# join the cluster using the shared token
# the IP we connect to is the one configured for the master node
# we skip CA verification due to this issue - https://github.com/kubernetes/kubeadm/issues/659
kubeadm join --token $TOKEN --discovery-token-unsafe-skip-ca-verification $MASTER_IP:6443

# copy each node's CNI configs into place after joining the cluster (seems that kubelet deletes /etc/cni/net.d when it joins a cluster)
mkdir -p /etc/cni/net.d
cp /config/$HOSTNAME/etc/cni/net.d/*.conf /etc/cni/net.d

# add iptables rules at the top of the FORWARD chain to allow all traffic on the CNI interface
iptables -I FORWARD 1 -o cni0 -j ACCEPT
iptables -I FORWARD 1 -i cni0 -j ACCEPT

# add cni0 bridge - this is done automatically by the CNI plugin if the bridge doesn't exist, but strongswan needs
# to be restarted after the bridge is added so we add it manually to make the startup cleaner
apt-get -y install bridge-utils
brctl addbr cni0
ip addr add $CNI_IP/24 dev cni0
ip link set dev cni0 up

# write the CNI IP to a file so we can use it again on startup
echo "export CNI_IP=$CNI_IP" > /usr/local/bin/cni-ip

# install strongswan
apt-get -y install strongswan

# strongswan is started by default after being installed, so stop it
systemctl stop strongswan.service

# copy global and node-specific strongswan configs into place
cp /config/global/etc/ipsec.secrets /etc/ipsec.secrets
cp /config/global/etc/strongswan.conf /etc/strongswan.conf
cp /config/$HOSTNAME/etc/ipsec.conf /etc/ipsec.conf

# copy code to handle restarts into place
cp /config/global/etc/systemd/system/cni-restart.service /etc/systemd/system
cp /config/global/usr/local/bin/cni-restart.sh /usr/local/bin/cni-restart.sh
chmod +x /usr/local/bin/cni-restart.sh

# create systemd override for strongswan
mkdir -p /etc/systemd/system/strongswan.service.d
cp /config/global/etc/systemd/system/strongswan.service.d/override.conf /etc/systemd/system/strongswan.service.d/override.conf
systemctl daemon-reload

# add line to charon apparmor policy to elimate syslog warning
echo "  @{PROC}/@{pid}/fd/    r," >> /etc/apparmor.d/local/usr.lib.ipsec.charon
systemctl reload apparmor.service

# enable and start strongswan service with newly installed configs
systemctl enable strongswan.service
systemctl restart strongswan.service

# enable CNI recreation service to run on restart
systemctl enable cni-restart.service
