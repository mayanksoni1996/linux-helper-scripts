#!/bin/bash

set -euo pipefail

TRUSTED_ZONE="trusted"
POD_CIDR="192.168.0.0/16"
WEBHOOK_PORT="443/tcp"

echo "[INFO] Configuring firewalld for Kubernetes pod networking..."

# Ensure firewalld is running
if ! systemctl is-active --quiet firewalld; then
    echo "[ERROR] firewalld is not running. Please start it first."
    exit 1
fi

echo "[INFO] Adding pod CIDR $POD_CIDR to $TRUSTED_ZONE..."
sudo firewall-cmd --permanent --zone=$TRUSTED_ZONE --add-source=$POD_CIDR || true

echo "[INFO] Adding port $WEBHOOK_PORT to $TRUSTED_ZONE..."
sudo firewall-cmd --permanent --zone=$TRUSTED_ZONE --add-port=$WEBHOOK_PORT || true

echo "[INFO] Adding Calico interfaces to $TRUSTED_ZONE..."
# Strip @ifX from interface names
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep '^cali' | cut -d'@' -f1); do
    echo " - Adding $iface..."
    sudo firewall-cmd --permanent --zone=$TRUSTED_ZONE --add-interface="$iface" || true
done

# Add vxlan.calico if it exists
if ip link show vxlan.calico &> /dev/null; then
    echo " - Adding vxlan.calico..."
    sudo firewall-cmd --permanent --zone=$TRUSTED_ZONE --add-interface="vxlan.calico" || true
fi

# Optional: Enable masquerading
echo "[INFO] Enabling masquerade in $TRUSTED_ZONE..."
sudo firewall-cmd --permanent --zone=$TRUSTED_ZONE --add-masquerade || true

# Reload firewall
echo "[INFO] Reloading firewalld..."
sudo firewall-cmd --reload

echo "[SUCCESS] firewalld rules updated for Kubernetes networking."
