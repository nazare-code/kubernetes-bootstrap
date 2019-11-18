#!/bin/bash

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
sudo bash -c "cat >>/etc/hosts<<EOF
192.168.192.10 jumping.example.com jumpingvm
192.168.192.100 kmaster.example.com kmaster
192.168.192.101 kworker1.example.com kworker1
192.168.192.102 kworker2.example.com kworker2
EOF"

#installing sshpass
echo "[TASK 2] Install sshpass"
sudo add-apt-repository universe >/dev/null 2>&1
sudo apt-get update >/dev/null 2>&1
sudo apt-get install sshpass >/dev/null 2>&1

#installing kubectl
echo "[TASK 3] Install kubectl"
sudo snap install kubectl --classic

# Copy Kube admin config
echo "[TASK 4] Copy kube admin config to Vagrant user .kube directory"
mkdir /home/vagrant/.kube
sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@192.168.192.100:/home/vagrant/.kube/config /home/vagrant/.kube/config 2>/dev/null
sudo chown -R vagrant:vagrant /home/vagrant/.kube

#installing helm
echo "[TASK 5] Install helm"
sudo snap install helm --classic

#Installing tiller
echo "[TASK 6] Install tiller"
helm init

#Create The Tiller Service Account
echo "[TASK 7] Install Tiller Service Account"
kubectl create serviceaccount tiller --namespace kube-system
#Bind The Tiller Service Account To The Cluster-Admin Role
cat <<EOF | kubectl apply -f -
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: tiller-clusterrolebinding
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: ""
EOF
#Update The Existing Tiller Deployment
helm init --service-account tiller --upgrade

#installing metallb
echo "[TASK 8] Install Metallb"
kubectl apply -f https://raw.githubusercontent.com/google/metallb/v0.8.3/manifests/metallb.yaml
#configuring metallb
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: metallb-system
  name: config
data:
  config: |
    address-pools:
    - name: default
      protocol: layer2
      addresses:
      - 192.168.192.230-192.168.192.250
EOF

#install nginx-ingress
echo "[TASK 9] Install nginx-ingress"
sleep 2m
helm install --name nginx-ingress stable/nginx-ingress

echo "Ready..."

