#!/bin/bash

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
sudo bash -c "cat >>/etc/hosts<<EOF
192.168.192.10 jumping.example.com jumpingvm
192.168.192.10 gitea.example.com gitea
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

#install docker engine
echo "[TASK 9] Install docker engine"
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common -y >/dev/null 2>&1
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - >/dev/null 2>&1
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable" >/dev/null 2>&1
sudo apt-get update >/dev/null 2>&1
sudo apt-get install docker-ce -y >/dev/null 2>&1
sudo systemctl enable docker >/dev/null 2>&1

#install docker-compose 
echo "[TASK 10] Install docker-compose"
sudo curl -L https://github.com/docker/compose/releases/download/1.21.2/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose >/dev/null 2>&1
sudo chmod +x /usr/local/bin/docker-compose >/dev/null 2>&1

#install gitea
echo "[TASK 11] Install gitea"
cat <<EOF > docker-compose.yml
version: "2"

networks:
  gitea:
    external: false

services:
  server:
    image: gitea/gitea:latest
    environment:
      - USER_UID=1000
      - USER_GID=1000
    restart: always
    networks:
      - gitea
    volumes:
      - ./gitea:/data
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    ports:
      - "3000:3000"
      - "222:22"
      - "8080:3000"
      - "2221:22"
EOF
sudo docker-compose up -d >/dev/null 2>&1
cat <<EOF > post_install_gitea.sh 
sed -i 's/SSH_DOMAIN       = localhost/SSH_DOMAIN       = gitea.example.com/g' /home/vagrant/gitea/gitea/conf/app.ini
sed -i 's/ROOT_URL         = http:\/\/localhost:3000\//ROOT_URL         = http:\/\/gitea.example.com\//g' /home/vagrant/gitea/gitea/conf/app.ini
sed -i 's/DOMAIN           =/DOMAIN           = example.com/g' /home/vagrant/gitea/gitea/conf/app.ini
sudo docker-compose stop
sudo docker-compose up -d
EOF

#install nginx-ingress
echo "[TASK 11] Install nginx-ingress"
helm install --name nginx-ingress stable/nginx-ingress

echo "Ready..."

