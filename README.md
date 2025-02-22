# Bootstrap K8s Cluster on AWS

## This is going to be 1 Master & 1 slave cluster.

### Step to follow on AWS:
  1- Create a RSA keypair.\
  2- Create 2 Security Groups, 1 for Master & 1 for Slave.\
    a) Allow "SSH" from your [IP](https://whatismyipaddress.com/).\
    b) Allow "All Traffic" from "Security Group of Slave(if rule is getting added on Master Security group)"  And add the vise versa for Slave Security Group.\
  3- Launch an ec2 instance of type t2.micro, tagged with name "k8s-master", OS: Ubuntu, Select "RSA Key pair" created earlier, attach Security group created for Master and paste content from [kubemaster.sh](Scripts/kubemaster.sh) in "User data" in "Advanced details" section.\
  4- Launch another ec2 instance of type t2.micro, tagged with name "k8s-node01", OS: Ubuntu, Select "RSA Key pair" created earlier, attach Security group created for Slave and paste content from [kubenode.sh](Scripts/kubenode.sh) in "User data" in "Advanced details" section.

### Note:
Don't use the above mentioned script if you want to learn cluster deployment using Kubeadm tool. These scripts will save your time if you need to deploy the cluster multiple times.
For now refer the below [Instructions](https://github.com/r4riyaz/bootstrap-kubernetes-cluster/edit/main/README.md#master-node) for respective nodes.\
If you're executing the scripts then you have to run "kubeadm join ...." command manually. You can get get the full command from file "/root/kube_init_output" on Master Node.



# Master Node:
## Enable IPv4 packet forwarding:
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#prerequisite-ipv4-forwarding-optional \
```
lsmod | grep -i br_netfilter
modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/k8s.conf
lsmod | grep -i br_netfilter
```
It's a single command starting from cat to the 3rd line EOF, make sure to copy and paste in one go.
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
```
```
sudo sysctl --system
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

## Install container runtime (Containerd):
```
sudo apt-get update
sudo apt-get install containerd -y
```
## Install Kubeadm, Kubelet and Kubectl:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
```
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Set the "systemd" cgroup driver for container runtime:
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
```
sudo mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
```

## Initialize control-plane node:
use "--ignore-preflight-errors='NumCPU,Mem'" to ignore below errors related to Less CPUs Memory on EC2 Instance only.\
You don't need to use it on local VM where we have CPUs 2 or more and memory 1700MB or more.
[ERROR NumCPU]: the number of available CPUs 1 is less than the required 2
[ERROR Mem]: the system RAM (957 MB) is less than the minimum 1700 MB
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/create-cluster-kubeadm/
```
PRIMARY_IP=$(ip route get 1.1.1.1 | awk '/via/ {print $7}')
kubeadm init --apiserver-advertise-address ${PRIMARY_IP} --pod-network-cidr '10.244.0.0/16' --upload-certs --ignore-preflight-errors='NumCPU,Mem' | sudo tee /root/kube_init_output
tail -30 /root/kube_init_output
```

## To start using your cluster, you need to run the following as a regular user:
```
smkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
chown $(id -u):$(id -g) $HOME/.kube/config
```
### Kubeadm token create (Optional):
If we miss the token output from "kubeadmin init" command then we can run below command to get token with the command to join the master node. Then run it on Worker node\
If you already have the "Kubeadm join" command with token to join the master node then ignore this.
```
kubeadm token create --print-join-command
```

## Install Network Addon - Flannel:
https://kubernetes.io/docs/concepts/cluster-administration/addons/#networking-and-network-policy
https://github.com/flannel-io/flannel#deploying-flannel-manually
```
sudo kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

## Configure shell autocomplition:
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-kubectl-autocompletion
```
echo 'source <(kubectl completion bash)' >> /root/.bashrc
source /root/.bashrc
```

# Worker Node:
## Enable IPv4 packet forwarding:
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#prerequisite-ipv4-forwarding-optional \
```
modprobe br_netfilter
echo "br_netfilter" > /etc/modules-load.d/k8s.conf
```
It's a single command starting from cat to the 3rd line EOF, make sure copy and paste in one go.
```
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
```
```
sudo sysctl --system
sysctl net.ipv4.ip_forward
sysctl net.bridge.bridge-nf-call-iptables
```

## Install container runtime:
```
sudo apt-get update
sudo apt-get install containerd -y
```
## Install Kubeadm, Kubelet and Kubectl:
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/
```
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
```

## Set the "systemd" cgroup driver for container runtime:
https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
```
sudo mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd
```

## Join the worker node with Master:
If you miss the token output from "kubeadm init" command on Master. just copy the "kubeadm join" command from /root/kube_init_output file from master node.
Demo Command (Don't copy paste it):
```
kubeadm join 172.31.4.28:6443 --token b0ygt8.9h3ik9osty4r50zu --discovery-token-ca-cert-hash sha256:eec7dd42c34a6f8d6f40a35723c7f39d59eb5aa582b3f289687269da1d81bb3d
```

## Configure shell autocomplition:
https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-kubectl-autocompletion
```
echo 'source <(kubectl completion bash)' >> /root/.bashrc
source /root/.bashrc
```
