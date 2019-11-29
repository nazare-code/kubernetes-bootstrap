#!/bin/bash

# Initialize Kubernetes
echo "[TASK 1] Initialize Kubernetes Cluster"
kubeadm init --apiserver-advertise-address=10.105.231.150 --pod-network-cidr=172.16.0.0/16 >> /root/kubeinit.log 2>/dev/null

# Copy Kube admin config
echo "[TASK 2] Copy kube admin config to Vagrant user .kube directory"
mkdir /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Deploy flannel network
echo "[TASK 3] Deploy Calico network"
su - vagrant -c "kubectl create -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml"

# Generate Cluster join command
echo "[TASK 4] Generate and save cluster join command to /joincluster.sh"
kubeadm token create --print-join-command > /joincluster.sh

# Patch deprecated API
echo "[TASK 5] Patch deprecated API"
sudo sed -i'.bak' '/^    - --tls-private-key-file=\/etc\/kubernetes\/pki\/apiserver.key.*/a\    \- --runtime-config=apps\/v1beta1=true,extensions\/v1beta1\/deployments=true' /etc/kubernetes/manifests/kube-apiserver.yaml
