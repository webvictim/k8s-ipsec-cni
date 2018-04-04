# shared token for joining kubernetes cluster
$cluster_token = "cxie6r.0gxsw80zf2xcti1d"

# global settings
$box = "generic/ubuntu1604"

# virtualbox settings
$virtualbox_cpus = 2 # will run with less, this just makes provisioning a bit quicker
$virtualbox_mem = 2048 # will run with less, this just makes provisioning a bit quicker

# libvirt settings
$libvirt_cpus = 1
$libvirt_mem = 1024

# master settings
$master_hostname = "kube-node1"
$master_ip = "192.168.64.10"

# worker settings
$node_count = 3
$node_base_hostname = "kube-node"
$node_base_ip = "192.168.64."
$node_base_ip_cni = "10.128."

# configs
Vagrant.configure("2") do |config|
  $node_count.times do |inc|
    node_hostname = "#{$node_base_hostname}#{inc+1}" # e.g. kube-node1, kube-node2 etc
    node_ip = "#{$node_base_ip}#{inc+1}0" # e.g. 192.168.64.10 for node1, 192.168.64.20 for node2 etc
    node_cni_ip = "#{$node_base_ip_cni}#{inc+1}.1" # e.g. 10.128.1.1 for node1, 10.128.2.1 for node2 etc
    node_cni_network = "#{$node_base_ip_cni}#{inc+1}.0/24" # e.g. 10.128.1.0/24 for node1, 10.128.2.0.24 for node2 etc

    config.vm.define node_hostname do |node|
      node.vm.box = $box
      node.vm.hostname = node_hostname
      node.vm.network "private_network", ip: node_ip
      node.vm.synced_folder "config", "/config", type: "nfs", nfs_udp: false
      node.vm.provider "libvirt" do |v|
        v.memory = $libvirt_mem
        v.cpus = $libvirt_cpus
      end
      node.vm.provider "virtualbox" do |v|
        v.memory = $virtualbox_mem
        v.cpus = $virtualbox_cpus
      end
      node.vm.provision "kube-baseline", type: "shell" do |script|
        script.path = "scripts/kube-baseline.sh"
      end
      node.vm.provision "master-provision", type: "shell" do |script|
        script.path = "scripts/master-provision.sh"
        script.env = { 'TOKEN' => $cluster_token, 'MASTER_IP' => $master_ip, 'HOSTNAME' => node_hostname, 'MASTER_HOSTNAME' => $master_hostname }
      end
      node.vm.provision "node-provision", type: "shell" do |script|
        script.path = "scripts/node-provision.sh"
        script.env = { 'TOKEN' => $cluster_token, 'MASTER_IP' => $master_ip, 'HOSTNAME' => node_hostname, 'MASTER_HOSTNAME' => $master_hostname }
      end
      node.vm.provision "cni-provision", type: "shell" do |script|
        script.path = "scripts/cni-provision.sh"
        script.env = { 'TOKEN' => $cluster_token, 'CNI_IP' => node_cni_ip, 'CNI_NETWORK' => node_cni_network }
      end
    end
  end
end

# -*- mode: ruby -*-
# vi: set ft=ruby :