#!/bin/bash

# This script configures firewalld to open the necessary ports and protocols for Calico.
# The Calico documentation recommends disabling the host firewall entirely.
# Use this script only if you are required to keep firewalld running.

# Check if firewalld service is active
if ! systemctl is-active --quiet firewalld; then
    echo "Firewalld is not running. Please start it with 'sudo systemctl start firewalld' if you intend to use it."
    exit 1
fi

echo "Opening required ports and protocols for Calico..."

# 1. Open TCP port 179 for Calico BGP communication
# This is required for communication between all Calico nodes.
echo "Adding TCP port 179 for BGP..."
sudo firewall-cmd --permanent --add-port=179/tcp

# 2. Allow IP-in-IP traffic (protocol number 4) for Calico networking
# This is a rich rule because IP-in-IP is a protocol, not a port.
echo "Adding IP-in-IP protocol (protocol 4)..."
sudo firewall-cmd --permanent --add-rich-rule='rule protocol value="ipencap" accept'

# 3. Open TCP port 6443 for Kubernetes API server
# This allows nodes to communicate with the Kubernetes API server.
# If your API server is on a different port (e.g., 443), change the port number below.
echo "Adding TCP port 6443 for Kubernetes API server..."
sudo firewall-cmd --permanent --add-port=6443/tcp

# Reload firewalld to apply the permanent changes
echo "Reloading firewalld to apply changes..."
sudo firewall-cmd --reload

echo "Firewall setup for Calico is complete. Please verify the rules with 'sudo firewall-cmd --list-all'."
