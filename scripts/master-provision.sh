#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# debugging
echo "TOKEN: $TOKEN"
echo "MASTER_IP: $MASTER_IP"

# randomly generated static token to ensure other nodes can join
kubeadm init --token $TOKEN --apiserver-advertise-address $MASTER_IP

# kubectl config for root
mkdir -p /root/.kube
cp -i /etc/kubernetes/admin.conf /root/.kube/config

# kubectl config for vagrant
mkdir -p /home/vagrant/.kube
cp -i /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube