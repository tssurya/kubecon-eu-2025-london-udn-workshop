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

Now you should be all set to follow the workshop through ! You should move to
the [pod](#pods) section, or to the [virtualisation](#virtualisation) section.

## Pods
This part of the demo will get the participants familiar with the concept of
`UserDefinedNetwork` (UDN). We will explore the following in detail:

1. What is a UDN and a CUDN
2. Creating UDNs and CUDNs to do network segmentation of a Kubernetes cluster
3. Creating pods and attaching them to these UDNs
4. Testing native network isolation across different UDNs
5. Creating LoadBalancer type services in these UDNs
6. Testing connectivity of clusterIP, nodePorts and LoadBalancerIP in these UDNs
7. Creating NetworkPolicy in these UDNs and testing connectivity
8. Ensuring Ingress and Egress works as expected for these UDN Pods
9. Concept of multi-homing for a pod in Kubernetes using UDNs
10. Creating pods in diffeernt UDNs with overlapping podIPs

All the commands required to be executed on your KIND cluster are
provided [here](https://github.com/tssurya/kubecon-eu-2025-london-udn-workshop/blob/main/manifests/udns-with-pods/commands-cheatsheet-for-participants.md).

Workshop instruction manual that will be followed can be found
[here](https://github.com/tssurya/kubecon-eu-2025-london-udn-workshop/blob/main/manifests/udns-with-pods/workshop-instructions-script.sh).

## Virtualisation
This part of the demo will focus on the virtualisation use cases. We will create
a cluster UDN, spanning across multiple namespaces, start a VM in each namespace,
and show east/west connectivity between them, as well as connectivity to the
outside world.

Afterwards, we will showcase VM live-migration between nodes, explain how we
ensure the VM IPAM configuration does not change during the migration, and
which shenanigans (yes, there are shenanigans ...) we have to perform to
preserve the established TCP connections during migration, for both IPv4 and
IPv6 IP families.

1. Apply the UDN and the workload manifests
```sh
kubectl apply -f kubecon-eu-2025-london-udn-workshop/manifests/virt/01-udn.yaml
kubectl apply -f kubecon-eu-2025-london-udn-workshop/manifests/virt/02-workloads.yaml
```

2. Wait for the VMs to be running
```sh
kubectl wait vmi -nred-namespace red --for=jsonpath='{.status.phase}'=Running
kubectl wait vmi -nblue-namespace blue --for=jsonpath='{.status.phase}'=Running
```

3. Log into the VMs and ensure egress works as expected
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

4. East/west traffic over the UDN
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

5. VM live-migration
In this scenario, we will establish a TCP connection between both red and blue
VMs using `iperf3`, then migrate the blue VM to another Kubernetes node. We
will see that the established TCP connection will survive the migration, while
a few packets will be lost.

Keep in mind we've seen in the previous step the `blue` VM IP address is
`192.168.0.4`.

Let's log into the blue VM and establish an `iperf3` server; as with the `red`
VM, the user/password is `fedora`/`fedora`.
```sh
[root@fc40 ~]# virtctl console -nblue-namespace blue
Successfully connected to blue console. The escape sequence is ^]

blue login: fedora
Password:
[fedora@blue ~]$ iperf3 -s -1 -p9000
-----------------------------------------------------------
Server listening on 9000 (test #1)
-----------------------------------------------------------
```

Let's now access the `red` VM, and connect to the `blue` VM:
```sh
[root@fc40 ~]# virtctl console -nred-namespace red
Successfully connected to red console. The escape sequence is ^]

--- 192.168.0.4 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1002ms
rtt min/avg/max/mdev = 3.327/4.943/6.560/1.616 ms
[fedora@red ~]$ iperf3 -c 192.168.0.4 -p 9000 -t 3600
Connecting to host 192.168.0.4, port 9000
[  5] local 192.168.0.3 port 47654 connected to 192.168.0.4 port 9000
[ ID] Interval           Transfer     Bitrate         Retr  Cwnd
[  5]   0.00-1.00   sec   564 MBytes  4.73 Gbits/sec    0   3.08 MBytes
[  5]   1.00-2.00   sec   452 MBytes  3.78 Gbits/sec    1   3.08 MBytes
[  5]   2.00-3.00   sec   616 MBytes  5.18 Gbits/sec    0   3.08 MBytes
[  5]   3.00-4.00   sec   426 MBytes  3.58 Gbits/sec    1   3.08 MBytes
[  5]   4.00-5.02   sec   588 MBytes  4.86 Gbits/sec    1   3.08 MBytes
[  5]   5.02-6.00   sec   585 MBytes  4.98 Gbits/sec    1   3.08 MBytes
...
```

Let's now issue the migrate command using the `virtctl` CLI:
```sh
[root@fc40 ~]# virtctl migrate -nblue-namespace blue
VM blue was scheduled to migrate
[root@fc40 ~]# kubectl get pods -nblue-namespace -w
NAME                       READY   STATUS            RESTARTS   AGE
virt-launcher-blue-crvf7   2/2     Running           0          29h
virt-launcher-blue-pzsrk   0/2     PodInitializing   0          8s
virt-launcher-blue-pzsrk   2/2     Running           0          12s
virt-launcher-blue-crvf7   1/2     NotReady          0          29h
virt-launcher-blue-pzsrk   2/2     Running           0          40s
virt-launcher-blue-pzsrk   2/2     Running           0          40s
virt-launcher-blue-pzsrk   2/2     Running           0          40s
virt-launcher-blue-pzsrk   2/2     Running           0          41s
virt-launcher-blue-crvf7   0/2     Completed         0          29h
virt-launcher-blue-crvf7   0/2     Completed         0          29h
```

You'll be ejected from the `blue` VM console, and you'll see something similar
to this in the `red` VM:
```sh
...
[  5]  70.00-71.03  sec   231 MBytes  1.89 Gbits/sec    0   1.90 MBytes
[  5]  71.03-72.01  sec  81.2 MBytes   698 Mbits/sec    0   2.02 MBytes
[  5]  72.01-73.02  sec   112 MBytes   934 Mbits/sec    0   2.08 MBytes
[  5]  73.02-74.00  sec   100 MBytes   852 Mbits/sec    2   1.32 KBytes
[  5]  74.00-75.02  sec  0.00 Bytes  0.00 bits/sec      1   1.32 KBytes
[  5]  75.02-76.00  sec  25.0 MBytes   213 Mbits/sec   24   1.32 KBytes
[  5]  76.00-77.00  sec   341 MBytes  2.87 Gbits/sec    3   3.01 MBytes
...
```
This concludes our live-migration demo.

