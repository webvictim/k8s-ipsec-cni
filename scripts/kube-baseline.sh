#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# set timezone to UTC
rm /etc/localtime && ln -s /usr/share/zoneinfo/UTC /etc/localtime

# install docker, kubelet, kubeadm and kubectl
# from https://kubernetes.io/docs/setup/independent/install-kubeadm/
# the key for the repo seems to have expired so we also need --allow-unauthenticated
apt-get update
apt-get install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb https://download.docker.com/linux/$(. /etc/os-release; echo "$ID") $(lsb_release -cs) stable"
apt-get update && apt-get install -y docker-ce=$(apt-cache madison docker-ce | grep 17.03 | head -1 | awk '{print $3}')
apt-get update && apt-get install -y apt-transport-https
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
apt-get update
apt-get install -y --allow-unauthenticated kubelet kubeadm kubectl

# disable swap if it's enabled (kubeadm preflight checks stipulate that it can't be on)
swapoff -a

# delete swap entry from /etc/fstab to make sure it doesn't come back at boot
sed -i '/UUID=d3461d2a-c518-4ed4-902d-ff23846c8ea7/d' /etc/fstab