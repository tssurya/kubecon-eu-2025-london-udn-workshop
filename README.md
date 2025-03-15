# kubecon-eu-2025-london-udn-workshop

## Requirements
This workshop is intended to be executed on a VM, so you don't have to pollute your local environment.

You'll require the following packages to run it:
- libvirt
- kvm
- QEMU
- guestfs-tools

The VM has the following requirements:
- 8 GBi RAM
- 100 GBi disk space

The VM will be created with the environment to run this demo.

Since part of the workshop will spin up VMs in the Kind cluster - thus creating VMs inside the workshop VM -
you need to enable nested virtualization in your hypervisor (laptop). While there are many options, we do
recommend the KVM / Libvirt / QEMU stack on
[fedora](https://docs.fedoraproject.org/en-US/fedora-server/virtualization/installation/).

To install the packages listed above, run the following command on your Hypervisor (assuming you're on Fedora ...):
```sh
dnf install qemu-kvm-core libvirt virt-install cockpit-machines guestfs-tools
```

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

4. Clone the workshop repo on the VM
```sh
git clone https://github.com/tssurya/kubecon-eu-2025-london-udn-workshop.git
```

5. Apply the UDN and the workload manifests
```sh
kubectl apply -f kubecon-eu-2025-london-udn-workshop/manifests/virt/01-udn.yaml
kubectl apply -f kubecon-eu-2025-london-udn-workshop/manifests/virt/02-workloads.yaml
```

6. Wait for the VMs to be running
```sh
kubectl wait vmi -nred-namespace red --for=jsonpath='{.status.phase}'=Running
kubectl wait vmi -nblue-namespace blue --for=jsonpath='{.status.phase}'=Running
```

7. Log into the VMs and ensure egress works as expected
Once the VMs are `Running`, we can now log into them via the console, using the `virtctl` CLI.
```sh
[root@fc40 ~]# virtctl console -nred-namespace red
Successfully connected to red console. The escape sequence is ^]

red login: fedora
Password:
[fedora@red ~]$ ip r
default via 192.168.0.1 dev eth0 proto dhcp metric 100
192.168.0.0/16 dev eth0 proto kernel scope link src 192.168.0.3 metric 100
[fedora@red ~]$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc fq_codel state UP group default qlen 1000
    link/ether 0a:58:c0:a8:00:03 brd ff:ff:ff:ff:ff:ff
    altname enp1s0
    inet 192.168.0.3/16 brd 192.168.255.255 scope global dynamic noprefixroute eth0
       valid_lft 3116sec preferred_lft 3116sec
    inet6 fe80::858:c0ff:fea8:3/64 scope link
       valid_lft forever preferred_lft forever
[fedora@red ~]$ ping -c 2 www.google.com
PING www.google.com (142.250.178.164) 56(84) bytes of data.
64 bytes from 142.250.178.164 (142.250.178.164): icmp_seq=1 ttl=56 time=32.3 ms
64 bytes from 142.250.178.164 (142.250.178.164): icmp_seq=2 ttl=56 time=31.3 ms

--- www.google.com ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1001ms
rtt min/avg/max/mdev = 31.340/31.795/32.250/0.455 ms
```

8. East/west traffic over the UDN
Let's also ensure the east/west traffic works as expected in the UDN. For that, we first need to figure out
the IP address of one VM, and ping from the other.
```sh
[root@fc40 ~]# kubectl get vmi -n blue-namespace blue -ojsonpath="{@.status.interfaces}" | jq
[
  {
    "infoSource": "domain, guest-agent",
    "interfaceName": "eth0",
    "ipAddress": "192.168.0.4",
    "ipAddresses": [
      "192.168.0.4"
    ],
    "linkState": "up",
    "mac": "0a:58:c0:a8:00:04",
    "name": "happy",
    "podInterfaceName": "ovn-udn1",
    "queueCount": 1
  }
]

# now from the other VM:
[root@fc40 ~]# virtctl console -nred-namespace red
Successfully connected to red console. The escape sequence is ^]

[fedora@red ~]$
[fedora@red ~]$ ping 192.168.0.4
PING 192.168.0.4 (192.168.0.4) 56(84) bytes of data.
64 bytes from 192.168.0.4: icmp_seq=1 ttl=64 time=6.56 ms
64 bytes from 192.168.0.4: icmp_seq=2 ttl=64 time=3.33 ms

--- 192.168.0.4 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 3.327/4.943/6.560/1.616 ms
```

