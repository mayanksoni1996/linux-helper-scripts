#!/bin/bash

# This script automates the installation of Kubernetes on Ubuntu
# based on the Rocky Linux script and adapted for Ubuntu 22.04 LTS.

# ---0. Updating the distro and downloading prerequisites----
echo "---- Performing Update and downloading required software --- "
sudo apt-get update -y
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release git tar wget

# --- 1. Disable Swap and Configure Kernel Parameters ---
echo "--- Disabling Swap and Configuring Kernel Parameters ---"

# Disable swap permanently
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap disabled and commented out in /etc/fstab"

# Configure kernel parameters
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

# --- 2. Configure Firewall Rules (UFW) ---
echo "--- Configuring UFW firewall rules ---"

# Ensure UFW is installed and running
sudo apt-get install -y ufw
sudo ufw enable
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Open necessary ports for Kubernetes control plane and nodes
# Control Plane Ports:
sudo ufw allow 6443/tcp comment 'Kubernetes API server'
sudo ufw allow 2379:2380/tcp comment 'etcd server client API'
sudo ufw allow 10250/tcp comment 'Kubelet API'
sudo ufw allow 10251/tcp comment 'Kube-scheduler'
sudo ufw allow 10252/tcp comment 'Kube-controller-manager'
# Worker Node Ports (also needed on control plane if it runs pods):
sudo ufw allow 30000:32767/tcp comment 'NodePort Services'
sudo ufw allow 10255/tcp comment 'Kubelet read-only port'
# Allow traffic for Flannel or other CNI (e.g., Calico uses port 179)
sudo ufw allow 179/tcp comment 'Calico BGP'

# Reload firewall rules (UFW is automatically reloaded on rule changes)
sudo ufw reload
echo "UFW firewall rules configured."

# --- 3. Install and Configure Containerd ---
echo "--- Installing and Configuring Containerd ---"

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y containerd.io

# Generate default containerd config and modify it to use systemd cgroup driver
sudo mkdir -p /etc/containerd
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Containerd installed and configured with systemd cgroup driver."

# --- 4. Add Kubernetes Repository ---
echo "--- Adding Kubernetes Repository ---"

# Add Kubernetes GPG key
sudo curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes apt repository
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -y
echo "Kubernetes repository added."

# --- 5. Install Kubeadm, Kubelet, and Kubectl ---
echo "--- Installing Kubeadm, Kubelet, and Kubectl ---"

# Install Kubernetes components
sudo apt-get install -y kubelet kubeadm kubectl

# Enable and start kubelet (it's often managed by the packages but good practice to ensure)
sudo systemctl enable --now kubelet
echo "Kubelet enabled and started."

# --- 6. Install Helm ---
echo "--- Installing Helm ---"
sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh
echo "Helm installed."

echo "--- Kubernetes pre-installation setup complete ---"
echo "You can now initialize the Kubernetes control plane on the master node using 'sudo kubeadm init'."
echo "On worker nodes, you can join the cluster using 'sudo kubeadm join ...'."
