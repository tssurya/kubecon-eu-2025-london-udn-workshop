#!/bin/bash

function run_cmd() {
    echo "# $@"

    "$@"
    read
}

function header() {
	echo "========================================================================================="
	echo "    $@"
	echo "========================================================================================="
}

header "KIND Cluster"
run_cmd virtctl version
run_cmd kubectl get pods -nkubevirt

header "Create red and blue namespaces; connect them via cluster UDN"
run_cmd kubectl apply -f ../manifests/virt/01-udn.yaml
run_cmd kubectl get ns -owide -l k8s.ovn.org/primary-user-defined-network

header "Inspect the cluster UDN for virtualization workloads"
run_cmd kubectl get clusterserdefinednetwork happy-tenant -oyaml

header "Create the VMs on the namespaces connected by the cluster UDN"
run_cmd kubectl apply -f ../manifests/virt/02-workloads.yaml

header "Wait for the VMs to be ready"
run_cmd kubectl wait vmi -nred-namespace red --for=jsonpath='{.status.phase}'=Running
run_cmd kubectl wait vmi -nblue-namespace blue --for=jsonpath='{.status.phase}'=Running

header "Get IP addresses of the RED VM"
run_cmd kubectl get vmi -nred-namespace red -ojsonpath='{@.status.interfaces}' | jq
run_cmd kubectl get vmi -nblue-namespace blue -ojsonpath='{@.status.interfaces}' | jq

header "Check egress connectivity on the RED VM"
#run_cmd ssh 

