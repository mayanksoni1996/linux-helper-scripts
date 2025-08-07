#!/bin/bash

sudo firewall-cmd --permanent --new-zone=calico-trusted
sudo firewall-cmd --permanent --zone=calico-trusted --set-target=ACCEPT
sudo firewall-cmd --permanent --zone=calico-trusted --add-interface=vxlan.calico
sudo firewall-cmd --permanent --zone=calico-trusted --add-interface=cali+
