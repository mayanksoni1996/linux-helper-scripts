#!/bin/bash

# This script initializes a Kubernetes cluster using kubeadm and installs Calico for pod networking.

echo "Initializing Kubernetes cluster..."

# Initialize the Kubernetes control plane with a specified pod network CIDR.
# The --pod-network-cidr is crucial for Calico to function correctly.
sudo kubeadm init --pod-network-cidr=192.168.0.0/16

# Create the .kube directory in the user's home directory if it doesn't exist.
mkdir -p $HOME/.kube

# Copy the Kubernetes admin configuration file to the user's .kube directory.
# This allows kubectl to interact with the cluster without requiring sudo.
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config

# Change the ownership of the kubeconfig file to the current user.
# This ensures that the current user has the necessary permissions to access the cluster.
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Kubernetes control plane initialized. Installing Calico..."

# Apply the Custom Resource Definitions (CRDs) for the Calico operator.
# These CRDs define the resources that the Calico operator will manage.
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/operator-crds.yaml

# Deploy the Calico operator itself.
# The operator will then manage the Calico installation based on custom resources.
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/tigera-operator.yaml

# Download the custom-resources.yaml file, which defines the Calico installation.
# This file specifies the desired state for the Calico network.
curl https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/custom-resources.yaml -O

# Apply the custom-resources.yaml file to deploy Calico.
# The Calico operator will read this file and set up the networking components.
kubectl create -f custom-resources.yaml

echo "Kubernetes cluster initialization and Calico installation complete."
echo "You should now be able to use kubectl to interact with your cluster."
