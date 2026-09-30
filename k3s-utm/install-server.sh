#!/usr/bin/env bash
set -euo pipefail

node_name=${1:?usage: bash install-server.sh NODE_NAME}
iface=enp0s1
node_ip=$(ip -4 -o addr show dev "$iface" | awk 'NR == 1 {split($4, a, "/"); print a[1]}')
test -n "$node_ip"
sudo test ! -e /etc/rancher/k3s/config.yaml
! command -v k3s >/dev/null 2>&1
test -z "$(swapon --noheadings --show)"

sudo install -d -m 700 /etc/rancher/k3s
sudo install -m 600 /dev/null /etc/rancher/k3s/agent-token
openssl rand -hex 32 | sudo tee /etc/rancher/k3s/agent-token >/dev/null
sudo tee /etc/rancher/k3s/config.yaml >/dev/null <<EOF
node-name: "$node_name"
node-ip: "$node_ip"
advertise-address: "$node_ip"
tls-san:
  - "$node_ip"
flannel-iface: "$iface"
agent-token-file: /etc/rancher/k3s/agent-token
EOF
sudo chmod 600 /etc/rancher/k3s/config.yaml

curl -fsSL https://get.k3s.io -o /tmp/install-k3s.sh
sudo sh /tmp/install-k3s.sh server
sudo k3s --version
sudo k3s kubectl get nodes -o wide
