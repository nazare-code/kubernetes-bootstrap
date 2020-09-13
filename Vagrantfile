# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  # Kubernetes Master Server
  config.vm.define "master" do |masternode|
    masternode.vm.box = "centos/7"
    masternode.vm.hostname = "master.nzr.io"
    masternode.vm.network "public_network", ip: "192.168.1.200"
    masternode.vm.provision "shell", run: "always", inline: "sudo ip route add 0.0.0.0/0 via 192.168.1.1"
    masternode.vm.provider "virtualbox" do |v|
      v.name = "master"
      v.memory = 1024
      v.cpus = 1
    end
    master.vm.provision "shell", path: "bootstrap.sh"
    master.vm.provision "shell", path: "bootstrap_master.sh"
  end

  NodeCount = 1

  # Kubernetes Worker Nodes
  (1..NodeCount).each do |i|
    config.vm.define "node#{i}" do |workernode|
      workernode.vm.box = "centos/7"
      workernode.vm.hostname = "node#{i}.nzr.io"
      workernode.vm.network "public_network", ip: "192.168.1.20#{i}"
      workernode.vm.provision "shell", run: "always", inline: "sudo ip route add 0.0.0.0/0 via 192.168.1.1"
      workernode.vm.provider "virtualbox" do |v|
        v.name = "node#{i}"
        v.memory = 1024
        v.cpus = 1
      end
     workernode.vm.provision "shell", path: "bootstrap.sh"
     workernode.vm.provision "shell", path: "bootstrap_node.sh"
    end
  end

  # Kubernetes Jumpbox VM
    config.vm.define "jumpingvm" do |node|
      node.vm.box = "ubuntu/bionic64"
      node.vm.hostname = "jumpbox.nzr.io"
      node.vm.network "public_network", ip: "192.168.1.213"
      node.vm.provision "shell", run: "always", inline: "sudo route add default gw 192.168.1.1 enp0s8"
      node.vm.provider "virtualbox" do |v|
        v.name = "jumpbox"
        v.memory = 1024
        v.cpus = 1
      end
      node.vm.provision "shell", path: "bootstrap_jumpbox.sh", privileged: false
      end
end
