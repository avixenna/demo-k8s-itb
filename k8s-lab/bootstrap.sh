#!/bin/bash
set -e

# =============================================================================
# WARNING: Script ini untuk LAB/DEVELOPMENT environment saja
# - Root password hardcoded
# - Root login enabled
# - Firewall disabled
# JANGAN gunakan untuk production
# =============================================================================

# setup SSH
echo "[TASK 1] Enable SSH password authentication"
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 2] Set root password"
echo -e "kubeadmin\nkubeadmin" | passwd root >/dev/null 2>&1

# Wajib untuk kubelet
echo "[TASK 3] Disable swap"
swapoff -a && sed -i '/ swap / s/^/#/' /etc/fstab

# Supaya networking antar node tidak diblok
# Untuk lab OK, tapi production sebaiknya configure firewall rule daripada disable total.
echo "[TASK 4] Disable UFW firewall"
systemctl disable ufw >/dev/null 2>&1 || true
systemctl stop ufw >/dev/null 2>&1 || true

# Agar iptables memproses paket dari container bridge
echo "[TASK 5] Load kernel modules & update sysctl for Kubernetes networking"
modprobe br_netfilter
cat <<EOF >/etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system >/dev/null 2>&1

# Mencegah error DNS di dalam pod
echo "[TASK 6] Set DNS resolvers"
mkdir -p /etc/systemd/resolved.conf.d
tee /etc/systemd/resolved.conf.d/dns.conf >/dev/null <<EOF
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=8.8.4.4 1.0.0.1
EOF
systemctl restart systemd-resolved

# Menjamin sistem terbaru sebelum install kubeadm/dockerd
echo "[TASK 7] Basic system update - skipped (proses lama: dilakukan manual dan pararel setelah vm dibuat)"
# apt-get update -y && apt-get upgrade -y

echo "[TASK 8] Install Microk8s"
# Ensure snapd is installed
if ! command -v snap &> /dev/null; then
    echo "Installing snapd..."
    apt-get update -qq && apt-get install -y snapd
fi
snap install microk8s --classic --channel=1.30/stable

usermod -a -G microk8s vagrant
# Fix .kube directory ownership for vagrant user
mkdir -p /home/vagrant/.kube
chown -R vagrant:vagrant /home/vagrant/.kube

echo "[TASK 9] Wait for MicroK8s to be ready and enable addons"
microk8s status --wait-ready
# Enable essential addons (storage akan pakai Longhorn)
microk8s enable dns
microk8s enable ingress

echo "[TASK 10] All task done"
echo "Node $(hostname) prepared successfully!"
