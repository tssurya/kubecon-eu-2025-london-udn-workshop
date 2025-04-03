# Virt scenario cheatsheet for workshop participants

## Introduction
- virtctl version
- kubectl get pods -nkubevirt

## Setting up the scenario
- kubectl apply -f ../manifests/virt/01-udn.yaml
- kubectl get ns -owide -l k8s.ovn.org/primary-user-defined-network
- kubectl get clusteruserdefinednetwork happy-tenant -oyaml
- kubectl apply -f ../manifests/virt/02-workloads.yaml
- kubectl get vmi -oyaml
- kubectl wait vmi -nred-namespace red --for=jsonpath='{.status.phase}'=Running
- kubectl wait vmi -nblue-namespace blue --for=jsonpath='{.status.phase}'=Running

## Testing connectivity
- blue_ip=$(kubectl get vmi -nblue-namespace blue -ojsonpath="{@.status.interfaces[].ipAddress}")
- virtctl -nred-namespace red console # user/passwd: fedora/fedora
- ping www.google.com
- ping $blue_ip

## Migration
- iperf3 -s -p9000 -1 # start iperf server on port 9000, accepting a single conn
- iperf3 -c $blue_ip -p9000 -t3600 # start iperf client to blue IP, port 9000
- virtctl migrate -nred-namespace red

