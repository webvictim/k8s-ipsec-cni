# shared token for joining kubernetes cluster
$cluster_token = "cxie6r.0gxsw80zf2xcti1d"

# global settings for all boxes
$box = "ubuntu/xenial64"

# master settings
$master_hostname = "kube-master"
$master_ip = "192.168.64.2"
$master_cpus = 2 # will run with less, this just makes provisioning quicker
$master_memory = 2048 # will run with less, this just makes provisioning quicker

# worker settings
$node_count = 3
$node_base_hostname = "kube-node"
$node_base_ip = "192.168.64."
$node_base_ip_cni = "10.128."
$node_cpus = 2 # will run with less, this just makes provisioning quicker
$node_memory = 2048 # will run with less, this just makes provisioning quicker

# configs
Vagrant.configure("2") do |config|
  config.vm.define "master" do |master|
    master.vm.box = $box
    master.vm.hostname = $master_hostname
    master.vm.network "private_network", ip: $master_ip
    master.vm.synced_folder "config", "/config"
    master.vm.provider "virtualbox" do |v|
      v.memory = $master_memory
      v.cpus = $master_cpus
    end
    master.vm.provision "kube-baseline", type: "shell" do |script|
      script.path = "scripts/kube-baseline.sh"
    end
    master.vm.provision "master-provision", type: "shell" do |script|
      script.path = "scripts/master-provision.sh"
      script.env = { 'TOKEN' => $cluster_token, 'MASTER_IP' => $master_ip, 'HOSTNAME' => $master_hostname }
    end
  end

  $node_count.times do |inc|
    node_hostname = "#{$node_base_hostname}#{inc+1}" # e.g. kube-node1, kube-node2 etc
    node_ip = "#{$node_base_ip}#{inc+1}0" # e.g. 192.168.64.10 for node1, 192.168.64.20 for node2 etc
    node_cni_ip = "#{$node_base_ip_cni}#{inc+1}.1" # e.g. 10.128.1.1 for node1, 10.128.2.1 for node2 etc

    config.vm.define node_hostname do |node|
      node.vm.box = $box
      node.vm.hostname = node_hostname
      node.vm.network "private_network", ip: node_ip
      node.vm.synced_folder "config", "/config"
      node.vm.provider "virtualbox" do |v|
        v.memory = $node_memory
        v.cpus = $node_cpus
      end
      node.vm.provision "kube-baseline", type: "shell" do |script|
        script.path = "scripts/kube-baseline.sh"
      end
      node.vm.provision "node-provision", type: "shell" do |script|
        script.path = "scripts/node-provision.sh"
        script.env = { 'TOKEN' => $cluster_token, 'MASTER_IP' => $master_ip, 'HOSTNAME' => node_hostname, 'CNI_IP' => node_cni_ip }
      end
    end
  end
end

# -*- mode: ruby -*-
# vi: set ft=ruby :