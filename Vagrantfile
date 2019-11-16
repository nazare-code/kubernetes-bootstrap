# -*- mode: ruby -*-
# vi: set ft=ruby :

ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure(2) do |config|

  # Kubernetes Master Server
  config.vm.define "kmaster" do |kmaster|
    kmaster.vm.box = "centos/7"
    kmaster.vm.hostname = "kmaster.example.com"
    kmaster.vm.network "private_network", ip: "192.168.192.100"
    kmaster.vm.provider "virtualbox" do |v|
      v.name = "kmaster"
      v.memory = 2048
      v.cpus = 2
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
      workernode.vm.network "private_network", ip: "192.168.192.10#{i}"
      workernode.vm.provider "virtualbox" do |v|
        v.name = "kworker#{i}"
        v.memory = 1024
        v.cpus = 1
      end
     workernode.vm.provision "shell", path: "bootstrap.sh"
     workernode.vm.provision "shell", path: "bootstrap_kworker.sh"
    end
  end

  # Kubernetes Jumping VM
    config.vm.define "jumpingvm" do |node|
      node.vm.box = "ubuntu/bionic64"
      node.vm.hostname = "jumpingvm.example.com"
      node.vm.network "private_network", ip: "192.168.192.10"
      node.vm.provider "virtualbox" do |v|
        v.name = "jumpingvm"
        v.memory = 2048
        v.cpus = 2
      end
      node.vm.provision "shell", path: "bootstrap_jumping.sh"
      end
end
