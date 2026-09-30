#!/usr/bin/env bash
set -euo pipefail

# Run on one of the three dedicated UTM Ubuntu VMs before installing K3s.
if command -v k3s >/dev/null 2>&1; then
  echo 'K3s is already installed; inspect this VM before reusing it.' >&2
  exit 1
fi

# Ubuntu allocated only part of the existing virtual disk to the root LV.
free_extents=$(sudo vgs --noheadings -o vg_free_count ubuntu-vg | tr -d '[:space:]')
if (( free_extents > 0 )); then
  sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
fi

# The default kubelet configuration refuses nodes with swap enabled.
sudo swapoff -a
if grep -Eq '^[^#].*[[:space:]]swap[[:space:]]' /etc/fstab; then
  if ! sudo test -e /etc/fstab.before-k3s; then
    sudo cp /etc/fstab /etc/fstab.before-k3s
  fi
  sudo sed -i '/^[^#].*[[:space:]]swap[[:space:]]/s/^/#/' /etc/fstab
fi

df -h /
swapon --show
