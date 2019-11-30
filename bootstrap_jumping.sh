#!/bin/bash

# Update hosts file
echo "[TASK 1] Update /etc/hosts file"
sudo bash -c "cat >>/etc/hosts<<EOF
10.105.231.13 jumping.example.com jumpingvm
10.105.231.13 gitlab.example.com gitlab
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
#sudo snap install helm --classic
sudo curl -L https://get.helm.sh/helm-v2.14.3-linux-amd64.tar.gz -o helm-v2.14.3.tar.gz >/dev/null 2>&1
sudo tar xvf helm-v2.14.3.tar.gz >/dev/null 2>&1
sudo mv linux-amd64/helm /usr/bin/
sudo mv linux-amd64/tiller /usr/bin/
sudo rm -Rf linux-amd64/ helm-v2.14.3.tar.gz
#sudo snap install helm --channel=2.16/stable --classic

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

#install gitlab
echo "[TASK 11] Install gitlab"
cat <<EOF > docker-compose.yml
web:
  image: 'gitlab/gitlab-ce:latest'
  restart: always
  hostname: 'gitlab.example.com'
  environment:
    GITLAB_OMNIBUS_CONFIG: |
      external_url 'https://gitlab.example.com'
  ports:
    - '80:80'
    - '443:443'
    - '30022:22'
  volumes:
    - '/srv/gitlab/config:/etc/gitlab'
    - '/srv/gitlab/logs:/var/log/gitlab'
    - '/srv/gitlab/data:/var/opt/gitlab'
EOF
sudo mkdir /srv/gitlab/config -p
sudo mkdir /srv/gitlab/logs -p
sudo mkdir /gitlab/data -p
sudo setfacl -Rm default:group:docker:rwx /srv/gitlab
sudo docker-compose up -d >/dev/null 2>&1

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
sudo /etc/init.d/nfs-kernel-server restart
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

#configuring firewall
echo "[TASK 15] configuring firewall rules for nfs"
sudo iptables -F >/dev/null 2>&1
sudo route delete default gw 10.0.2.2
sudo systemctl restart docker

#install jx
echo "[TASK 16]" Install jx
sudo curl -L "https://github.com/jenkins-x/jx/releases/download/$(curl --silent "https://github.com/jenkins-x/jx/releases/latest" | sed 's#.*tag/\(.*\)\".*#\1#')/jx-linux-amd64.tar.gz" | tar xzv "jx" >/dev/null 2>&1
sudo mv jx /usr/local/bin

echo "Ready..."

