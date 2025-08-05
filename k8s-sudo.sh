#!/bin/bash

# This script automates the installation of Kubernetes on Rocky Linux 9
# based on the guide: https://medium.com/@redswitches/install-kubernetes-on-rocky-linux-9-b01909d6ba72
# ---0. Updating the distro and downloading firewalld----
echo "---- Performing Update and downloading required software --- " 
dnf install -y epel-release 
dnf install -y firewalld git tar curl wget
# --- 1. Disable SELinux and Swap ---
echo "--- Disabling SELinux and Swap ---"

# Disable SELinux permanently
sudo setenforce 0
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
echo "SELinux status after temporary disable: $(getenforce)"
echo "SELINUX=permissive set in /etc/selinux/config"

# Disable swap permanently
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "Swap disabled and commented out in /etc/fstab"

# --- 2. Configure Firewall Rules (Firewalld) ---
echo "--- Configuring FirewallD rules ---"

# Ensure firewalld is running
sudo systemctl enable --now firewalld

# Open necessary ports for Kubernetes control plane and nodes
# Control Plane Ports:
sudo firewall-cmd --add-port=6443/tcp --permanent # Kubernetes API server
sudo firewall-cmd --add-port=2379-2380/tcp --permanent # etcd server client API
sudo firewall-cmd --add-port=10250/tcp --permanent # Kubelet API
sudo firewall-cmd --add-port=10251/tcp --permanent # Kube-scheduler
sudo firewall-cmd --add-port=10252/tcp --permanent # Kube-controller-manager
# HTTP Ports
sudo firewall-cmd --add-port=80/tcp --permanent
sudo firewall-cmd --add-port=443/tcp --permanent

# Worker Node Ports (also needed on control plane if it runs pods):
sudo firewall-cmd --add-port=30000-32767/tcp --permanent # NodePort Services
sudo firewall-cmd --add-port=10255/tcp --permanent # Kubelet read-only port (deprecated but often useful)
sudo firewall-cmd --add-port=179/tcp --permanent

# Reload firewall rules
sudo firewall-cmd --reload
echo "Firewall rules configured and reloaded."

# --- 3. Install and Configure Containerd ---
echo "--- Installing and Configuring Containerd ---"

# Add containerd configuration for systemd cgroup driver
sudo mkdir -p /etc/modules-load.d
cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# Setup necessary sysctl parameters for Kubernetes networking
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

# Install containerd
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce

# Generate default containerd config and modify it to use systemd cgroup driver
sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# Restart and enable containerd
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "Containerd installed and configured with systemd cgroup driver."

# --- 4. Add Kubernetes Repository ---
echo "--- Adding Kubernetes Repository ---"

# Add Kubernetes yum repository
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

# Update dnf cache
sudo dnf makecache
echo "Kubernetes repository added."

# --- 5. Install Kubeadm, Kubelet, and Kubectl ---
echo "--- Installing Kubeadm, Kubelet, and Kubectl ---"

# Install Kubernetes components
sudo dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Enable and start kubelet
sudo systemctl enable --now kubelet
echo "Kubelet enabled and started."

sudo curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
sudo chmod 700 get_helm.sh
sudo ./get_helm.sh

echo "--- Kubernetes pre-installation setup complete ---"
echo "You can now initialize the Kubernetes control plane on the master node using 'sudo kubeadm init'."
echo "On worker nodes, you can join the cluster using 'sudo kubeadm join ...'."
