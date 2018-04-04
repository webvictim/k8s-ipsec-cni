#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive
HOSTNAME=$(hostname)

# debugging
echo "TOKEN: $TOKEN"
echo "MASTER_IP: $MASTER_IP"
echo "MASTER_HOSTNAME: $MASTER_HOSTNAME"
echo "HOSTNAME: $HOSTNAME"

if [ "$HOSTNAME" != "$MASTER_HOSTNAME" ]; then
    echo "master-provision: not running because this is not the master node"
    exit 0
fi

# randomly generated static token to ensure other nodes can join
kubeadm init --token $TOKEN --apiserver-advertise-address $MASTER_IP

# kubectl config for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# kubectl config for vagrant
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# remote taint from master node so that pods can be scheduled on it
kubectl taint nodes kube-node1 node-role.kubernetes.io/master:NoSchedule-