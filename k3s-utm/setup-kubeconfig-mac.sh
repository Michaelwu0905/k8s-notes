#!/usr/bin/env bash
set -euo pipefail

# Run on the Mac. Keep the administrator kubeconfig outside this tutorial folder.
dest="$HOME/.kube/k3s-utm.yaml"
server_ip=$(ssh -o BatchMode=yes k3s-master 'ip -4 -o addr show dev enp0s1' | awk 'NR == 1 {split($4, a, "/"); print a[1]}')
test -n "$server_ip"
mkdir -p "$HOME/.kube"
if test -e "$dest"; then
  echo "Refusing to overwrite $dest" >&2
  exit 1
fi

umask 077
tmp=$(mktemp "$HOME/.kube/k3s-utm.yaml.XXXXXX")
trap 'rm -f "$tmp"' EXIT
ssh -o BatchMode=yes k3s-master 'sudo cat /etc/rancher/k3s/k3s.yaml' > "$tmp"
test -s "$tmp"
sed -i '' "s#server: https://127.0.0.1:6443#server: https://${server_ip}:6443#" "$tmp"
kubectl --kubeconfig "$tmp" get nodes -o wide
mv "$tmp" "$dest"
trap - EXIT
echo "Saved admin kubeconfig to $dest"
