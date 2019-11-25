#!/bin/bash

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
sudo bash -c "cat >>/etc/hosts<<EOF
10.105.231.13 jumping.example.com jumpingvm
10.105.231.13 gitea.example.com gitea
10.105.231.150 kmaster.example.com kmaster
10.105.231.151 kworker1.example.com kworker1
10.105.231.152 kworker2.example.com kworker2
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
sshpass -p "kubeadmin" scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no root@10.105.231.150:/home/vagrant/.kube/config /home/vagrant/.kube/config 2>/dev/null
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
      - 10.105.231.240-10.105.231.254
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
      - "80:3000"
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
echo "[TASK 12] Install nginx-ingress"
helm install --name nginx-ingress stable/nginx-ingress --namespace kube-system

#install nfs-server
echo "[TASK 13] Install nfs server"
sudo apt-get install nfs-common nfs-kernel-server -y>/dev/null 2>&1
sudo mkdir /srv/nfs/kubedata -p
sudo chown nobody: /srv/nfs/kubedata
sudo bash -c "cat >>/etc/exports<<EOF
/srv/nfs/kubedata       *(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)
EOF"
sudo systemctl enable nfs-server
sudo systemctl start nfs-server
sudo exportfs -v

#install nfs-provisioner
echo "[TASK 14] Install nfs provisioner"
cat <<EOF | kubectl apply -f -
kind: ServiceAccount
apiVersion: v1
metadata:
  name: nfs-client-provisioner
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: nfs-client-provisioner-runner
rules:
  - apiGroups: [""]
    resources: ["persistentvolumes"]
    verbs: ["get", "list", "watch", "create", "delete"]
  - apiGroups: [""]
    resources: ["persistentvolumeclaims"]
    verbs: ["get", "list", "watch", "update"]
  - apiGroups: ["storage.k8s.io"]
    resources: ["storageclasses"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["events"]
    verbs: ["create", "update", "patch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: run-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    namespace: default
roleRef:
  kind: ClusterRole
  name: nfs-client-provisioner-runner
  apiGroup: rbac.authorization.k8s.io
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
rules:
  - apiGroups: [""]
    resources: ["endpoints"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
---
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: leader-locking-nfs-client-provisioner
subjects:
  - kind: ServiceAccount
    name: nfs-client-provisioner
    # replace with namespace where provisioner is deployed
    namespace: default
roleRef:
  kind: Role
  name: leader-locking-nfs-client-provisioner
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
provisioner: example.com/nfs
parameters:
  archiveOnDelete: "false"
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: managed-nfs-storage
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: example.com/nfs
parameters:
  archiveOnDelete: "false"
---
kind: Deployment
apiVersion: apps/v1
metadata:
  name: nfs-client-provisioner
spec:
  replicas: 1
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: nfs-client-provisioner
  template:
    metadata:
      labels:
        app: nfs-client-provisioner
    spec:
      serviceAccountName: nfs-client-provisioner
      containers:
        - name: nfs-client-provisioner
          image: quay.io/external_storage/nfs-client-provisioner:latest
          volumeMounts:
            - name: nfs-client-root
              mountPath: /persistentvolumes
          env:
            - name: PROVISIONER_NAME
              value: example.com/nfs
            - name: NFS_SERVER
              value: 10.105.231.13
            - name: NFS_PATH
              value: /srv/nfs/kubedata
      volumes:
        - name: nfs-client-root
          nfs:
            server: 10.105.231.13
            path: /srv/nfs/kubedata
EOF

#remove firewall
echo "[TASK 15] remove firewall"
sudo apt-get remove iptables -y >/dev/null 2>&1

echo "Ready..."

