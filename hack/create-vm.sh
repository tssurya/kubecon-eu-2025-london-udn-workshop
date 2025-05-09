#!/bin/bash
set -xe

[ -n "${1}" ] || exit 1

name=$1

rootpassword=123456
osvariant=fedora40

partition=sda1
if [ $osvariant == fedora40 ] ; then
  version=40
  image_ver=1.14
  mirror=https://download.fedoraproject.org/pub/fedora/linux/releases/$version/Cloud/x86_64/images/
  origfile=Fedora-Cloud-Base-Generic.x86_64-$version-$image_ver.qcow2
else
  exit 1
fi

URI=qemu:///system

wget -nc $mirror/$origfile
virt-customize -a $origfile --update \
    --run-command "dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo" \
    --selinux-relabel
 virt-customize -a $origfile \
    --install vim,tmux,git,wget,direnv,zsh,make,docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin,curl,jq,openssl,golang,python3-pip \
    --firstboot-command "systemctl enable --now docker && sysctl -w net.ipv6.conf.all.forwarding=1" \
    --run-command "[ $(uname -m) = x86_64 ] && curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.27.0/kind-linux-amd64 && chmod +x kind && mv kind /usr/local/bin && VERSION=$(curl -s https://storage.googleapis.com/kubevirt-prow/release/kubevirt/kubevirt/stable.txt) && ARCH=$(uname -s | tr A-Z a-z)-$(uname -m | sed 's/x86_64/amd64/') || windows-amd64.exe && curl -L -o virtctl https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/virtctl-${VERSION}-${ARCH} && chmod +x virtctl && install virtctl /usr/local/bin && curl -LO \"https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\" && chmod +x kubectl && install kubectl /usr/local/bin" \
    --selinux-relabel

image=$name.img
truncate -s 80G $image
virt-resize -v -x $origfile $image --resize /dev/sda4=75G

virt-customize -a $image \
    --root-password password:$rootpassword \
    --ssh-inject root \
    --selinux-relabel \
    --hostname $name \
    --timezone "Europe/Madrid"

if [[ $distro_cmd ]]; then
 virt-customize -a $image \
    --run-command "$distro_cmd"
fi

mem="8192,maxmemory=16384"

sudo virt-install --name $name \
    --os-variant=$osvariant \
    --vcpus 4,maxvcpus=8 \
    --cpu host \
    --memory $mem \
    --rng /dev/urandom \
    --import \
    --disk $image \
    --noautoconsole \
    --network network=default \
    --connect $URI &

echo "... let's give it some time ..."
sleep 30
echo "Connecting to the VMI ..."
virsh -c qemu:///system domifaddr $name --source agent || virsh -c qemu:///system domifaddr $name

