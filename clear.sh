#!/bin/bash
set -u

echo "===== Accordion / Kubernetes Full Clean Reset ====="

echo "[1] Stop services"
systemctl stop kubelet containerd crio podman.socket 2>/dev/null || true
systemctl disable kubelet containerd 2>/dev/null || true

echo "[2] Remove podman containers / volumes"
podman rm -af 2>/dev/null || true
podman volume rm -af 2>/dev/null || true
podman system prune -af 2>/dev/null || true

echo "[3] Unmount container/kube mounts"
for m in $(mount | grep -E 'container|registry|kubelet|pods' | awk '{print $3}' | sort -r); do
  echo "umount -lf $m"
  umount -lf "$m" 2>/dev/null || true
done

echo "[4] kubeadm reset"
command -v kubeadm >/dev/null 2>&1 && kubeadm reset -f || true

echo "[5] Remove Kubernetes files"
rm -rf /etc/kubernetes /var/lib/etcd /var/lib/kubelet
rm -rf /etc/cni /opt/cni /var/lib/cni /run/flannel
rm -rf /root/.kube /home/*/.kube 2>/dev/null || true

echo "[6] Remove container runtime files"
rm -rf /etc/containerd /etc/containers
rm -rf /var/lib/containerd /var/lib/containers /run/containerd

echo "[7] Remove Accordion local files"
rm -rf /var/lib/accordion /opt/accordion /data/accordion

echo "[8] Remove NFS data"
if [ -d /nfs/data ]; then
  rm -rf /nfs/data/*
  mkdir -p /nfs/data
  chmod 755 /nfs/data
fi

echo "[X] Remove installer temp files"
rm -rf /tmp/1_containerd
rm -rf /tmp/6_kube
rm -rf /tmp/7_podman
rm -rf /tmp/rpms
rm -rf /tmp/ansible_*
rm -rf /tmp/tmp_*
rm -f /tmp/*.rpm

echo "[9] Remove remaining users/groups"
id etcd >/dev/null 2>&1 && userdel -rf etcd 2>/dev/null || true
getent group etcd >/dev/null 2>&1 && groupdel etcd 2>/dev/null || true

echo "[10] Remove CNI interfaces"
ip link delete cni0 2>/dev/null || true
ip link delete flannel.1 2>/dev/null || true
ip link delete kube-ipvs0 2>/dev/null || true
for i in $(ip -o link show | awk -F': ' '{print $2}' | grep '^cali'); do
  ip link delete "$i" 2>/dev/null || true
done

echo "[11] Flush iptables"
iptables -F 2>/dev/null || true
iptables -t nat -F 2>/dev/null || true
iptables -t mangle -F 2>/dev/null || true
iptables -X 2>/dev/null || true

echo "[12] Remove packages"
dnf remove -y kubeadm kubectl kubelet kubernetes-cni 2>/dev/null || true
dnf remove -y containerd.io podman buildah skopeo cri-tools 2>/dev/null || true
dnf autoremove -y 2>/dev/null || true

echo "[13] Verification"
echo "---- Remaining mounts ----"
mount | grep -E 'container|registry|kubelet|pods|nfs' || true

echo "---- Remaining interfaces ----"
ip a | grep -E 'cni|flannel|cali|kube-ipvs' || true

echo "---- Remaining packages ----"
rpm -qa | grep -E 'kube|containerd|podman' || true

echo "---- Remaining users/groups ----"
getent passwd etcd || true
getent group etcd || true

echo "---- /nfs/data ----"
ls -al /nfs/data 2>/dev/null || true

echo "===== CLEAN RESET COMPLETE ====="
echo "REBOOT THIS NODE NOW"
