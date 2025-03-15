# kubecon-eu-2025-london-udn-workshop

## Requirements
This workshop is intended to be executed on a VM, so you don't have to pollute your local environment.

You'll require the following packages to run it:
- libvirt
- kvm
- QEMU

The VM has the following requirements:
- 8 GBi RAM
- 100 GBi disk space

The VM will be created with the environment to run this demo.

## Creating the VM
1. Clone our workshop repo
```sh
git clone https://github.com/tssurya/kubecon-eu-2025-london-udn-workshop.git
```

2. Run the VM creation script. It'll take some time, since it has to pull a bunch of packages.
```sh
hack/create-vm.sh fc40
+ '[' -n fc40 ']'
+ name=fc40
+ rootpassword=123456
+ osvariant=fedora40
+ partition=sda1
+ '[' fedora40 == fedora40 ']'
+ version=40
+ image_ver=1.14
+ mirror=https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images/
+ origfile=Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2
+ URI=qemu:///system
+ wget -nc https://download.fedoraproject.org/pub/fedora/linux/releases/40/Cloud/x86_64/images//Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2
Nothing to do - goodbye
+ virt-customize -a Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2 --update
[   0.0] Examining the guest ...
[   9.8] Setting a random seed
[   9.8] Updating packages
[  10.9] SELinux relabelling
[  18.3] Finishing off
+ virt-customize -a Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2 --run-command 'dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo' --selinux-relabel
[   0.0] Examining the guest ...
[   9.2] Setting a random seed
[   9.3] Running: dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
[   9.8] SELinux relabelling
[  17.3] Finishing off
+ virt-customize -a Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2 --install vim,tmux,git,wget,direnv,zsh,make,docker-ce,docker-ce-cli,containerd.io,docker-buildx-plugin,docker-compose-plugin,curl,jq,openssl,golang --selinux-relabel
[   0.0] Examining the guest ...
[   8.6] Setting a random seed
[   8.6] Installing packages: vim tmux git wget direnv zsh make docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin curl jq openssl golang
[   9.7] SELinux relabelling
[  17.5] Finishing off
+ image=fc40.img
+ truncate -s 80G fc40.img
+ virt-resize -v -x Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2 fc40.img --resize /dev/sda4=75G
command line: virt-resize -v -x Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2 fc40.img --resize /dev/sda4=75G
[   0.0] Examining Fedora-Cloud-Base-Generic.x86_64-40-1.14.qcow2
...
virt-resize: Resize operation completed with no errors.  Before deleting 
the old disk, carefully check that the resized disk boots and works 
correctly.
+ virt-customize -a fc40.img --root-password password:123456 --ssh-inject root --selinux-relabel --hostname fc40 --timezone Europe/Madrid --uninstall cloud-init,kexec-tools,postfix
[   0.0] Examining the guest ...
[   6.7] Setting a random seed
[   6.7] SSH key inject: root
[   7.3] Setting the hostname: fc40
[   7.3] Setting the timezone: Europe/Madrid
[   7.3] Uninstalling packages: cloud-init kexec-tools postfix
[   9.5] Setting passwords
[  10.1] SELinux relabelling
[  17.0] Finishing off
+ [[ -n '' ]]
+ mem=8192,maxmemory=16384
+ echo '... let'\''s give it some time ...'
... let's give it some time ...
+ sleep 30
+ sudo virt-install --name fc40 --os-variant=fedora40 --vcpus 4,maxvcpus=8 --cpu host --memory 8192,maxmemory=16384 --rng /dev/urandom --import --disk fc40.img --noautoconsole --network network=default --connect qemu:///system
[sudo] password for mduarted: 

Starting install...
Creating domain...                                                                                                                                  |    0 B  00:00:00     
Domain creation completed.
+ echo 'Connecting to the VMI ...'
Connecting to the VMI ...
+ virsh -c qemu:///system domifaddr fc40 --source agent
 Name       MAC address          Protocol     Address
-------------------------------------------------------------------------------
 lo         00:00:00:00:00:00    ipv4         127.0.0.1/8
 -          -                    ipv6         ::1/128
 eth0       52:54:00:fb:cd:2a    ipv4         192.168.122.68/24
 -          -                    ipv6         fe80::7d12:6ca4:4962:3c65/64
```

Now you can connect to the VM using the information provided above:
```sh
ssh root@192.168.122.68 -P123456
```

## Creating the Kubernetes cluster using Kind
Next we want to setup a kind cluster with all the dependencies. For that,
you should clone the OVN-Kubernetes repo, and run its helper script.

1. Clone the OVN-Kubernetes repo
```sh
git clone https://github.com/ovn-kubernetes/ovn-kubernetes.git
```

2. Run the kind cluster creation script. This will give you a kind cluster with the UDN feature installed,
and KubeVirt deployed.
```sh
pushd ovn-kubernetes/contrib/ && ./kind.sh -ic -mne -nse -i6 -ikv && popd
```

3. Export the kind cluster kubeconfig
```sh
kind export kubeconfig --name ovn
```
