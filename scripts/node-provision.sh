#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# debugging
echo "TOKEN: $TOKEN"
echo "MASTER_IP: $MASTER_IP"
echo "HOSTNAME: $HOSTNAME"
echo "MASTER_HOSTNAME: $MASTER_HOSTNAME"

if [ "$HOSTNAME" == "$MASTER_HOSTNAME" ]; then
    echo "node-provision: not running because this is the master node"
    exit 0
fi

# join the cluster using the shared token
# the IP we connect to is the one configured for the master node
# we skip CA verification due to this issue - https://github.com/kubernetes/kubeadm/issues/659
kubeadm join --token $TOKEN --discovery-token-unsafe-skip-ca-verification $MASTER_IP:6443