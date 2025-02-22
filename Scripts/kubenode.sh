#!/bin/bash

echo "======= Enabling IPv4 packet forwarding ======="; sleep 2
##https://kubernetes.io/docs/setup/production-environment/container-runtimes/#prerequisite-ipv4-forwarding-optional
##It's a single command starting from cat to the 3rd line EOF, make sure copy and paste in one go.
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system


echo "======= Installing container runtime ======="; sleep 2
sudo apt-get update
sudo apt-get install containerd -y

echo "======= Installing Kubeadm, Kubelet and Kubectl ======="; sleep 2
##https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

sudo apt-get install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

echo "======= Setting up the systemd cgroup driver for container runtime ======="; sleep 2
##https://kubernetes.io/docs/setup/production-environment/container-runtimes/#containerd
sudo mkdir -p /etc/containerd
containerd config default | sed 's/SystemdCgroup = false/SystemdCgroup = true/g' | sudo tee /etc/containerd/config.toml
sudo systemctl restart containerd

echo "======= Configuring shell autocomplition ======";sleep 2
#https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/#enable-kubectl-autocompletion
echo 'source <(kubectl completion bash)' >> /root/.bashrc
source /root/.bashrc

echo "====== K8s slave server initialization completed ======="
echo "Now, navigate to k8s-master server and get the command from file /root/kube_init_output to join the slave with master node.."
