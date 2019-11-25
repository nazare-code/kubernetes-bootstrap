# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  # Kubernetes Master Server
  config.vm.define "kmaster" do |kmaster|
    kmaster.vm.box = "centos/7"
    kmaster.vm.hostname = "kmaster.example.com"
    kmaster.vm.network "public_network", ip: "10.105.231.150"
    kmaster.vm.provision "shell", run: "always", inline: "sudo ip route add 0.0.0.0/0 via 10.105.231.1"
    kmaster.vm.provider "virtualbox" do |v|
      v.name = "kmaster"
      v.memory = 4096
      v.cpus = 4
    end
    kmaster.vm.provision "shell", path: "bootstrap.sh"
    kmaster.vm.provision "shell", path: "bootstrap_kmaster.sh"
  end

  NodeCount = 2

  # Kubernetes Worker Nodes
  (1..NodeCount).each do |i|
    config.vm.define "kworker#{i}" do |workernode|
      workernode.vm.box = "centos/7"
      workernode.vm.hostname = "kworker#{i}.example.com"
      workernode.vm.network "public_network", ip: "10.105.231.15#{i}"
      workernode.vm.provision "shell", run: "always", inline: "sudo ip route add 0.0.0.0/0 via 10.105.231.1"
      workernode.vm.provider "virtualbox" do |v|
        v.name = "kworker#{i}"
        v.memory = 4096
        v.cpus = 4
      end
     workernode.vm.provision "shell", path: "bootstrap.sh"
     workernode.vm.provision "shell", path: "bootstrap_kworker.sh"
    end
  end

  # Kubernetes Jumping VM
    config.vm.define "jumpingvm" do |node|
      node.vm.box = "ubuntu/bionic64"
      node.vm.hostname = "jumpingvm.example.com"
      node.vm.network "public_network", ip: "10.105.231.13"
      node.vm.provision "shell", run: "always", inline: "sudo route add default gw 10.105.231.1 enp0s8"
      node.vm.provider "virtualbox" do |v|
        v.name = "jumpingvm"
        v.memory = 4096
        v.cpus = 4
      end
      node.vm.provision "shell", path: "bootstrap_jumping.sh", privileged: false
      end
end
