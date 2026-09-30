#!/usr/bin/env bash
set -euo pipefail

node_name=${1:?usage: bash install-agent.sh NODE_NAME SERVER_IP K3S_VERSION}
server_ip=${2:?usage: bash install-agent.sh NODE_NAME SERVER_IP K3S_VERSION}
k3s_version=${3:?usage: bash install-agent.sh NODE_NAME SERVER_IP K3S_VERSION}
iface=enp0s1
node_ip=$(ip -4 -o addr show dev "$iface" | awk 'NR == 1 {split($4, a, "/"); print a[1]}')
test -n "$node_ip"
sudo test -f /etc/rancher/k3s/join-token
sudo test ! -e /etc/rancher/k3s/config.yaml
! command -v k3s >/dev/null 2>&1
test -z "$(swapon --noheadings --show)"

sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<EOF
node-name: "$node_name"
node-ip: "$node_ip"
flannel-iface: "$iface"
server: "https://${server_ip}:6443"
token-file: /etc/rancher/k3s/join-token
EOF
sudo chmod 600 /etc/rancher/k3s/config.yaml

curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
sudo env INSTALL_K3S_VERSION="$k3s_version" sh /tmp/install-k3s.sh agent
sudo k3s --version
sudo systemctl is-active k3s-agent
