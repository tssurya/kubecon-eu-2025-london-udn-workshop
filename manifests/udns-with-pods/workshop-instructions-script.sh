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
run_cmd kubectl version

header "KIND Cluster Setup"
run_cmd kubectl get nodes -owide
run_cmd kubectl get pods -n ovn-kubernetes -owide
run_cmd kubectl get pods -n kubevirt -owide

header "Create four namespaces"
run_cmd kubectl apply -f ns.yaml
run_cmd kubectl get ns -owide -l k8s.ovn.org/primary-user-defined-network

header "Create two user-defined-networks one in blue and one in green namespaces"
run_cmd cat udns.yaml
run_cmd kubectl apply -f udns.yaml
run_cmd kubectl get userdefinednetwork -A -l purpose=kubecon-eu-2025-demo

header "Inspect the Layer3 UDNs"
run_cmd kubectl get userdefinednetwork -n blue -oyaml
run_cmd kubectl get userdefinednetwork -n green -oyaml

header "Create a cluster-user-defined-network connecting red and yellow namespaces"
run_cmd cat cudns.yaml
run_cmd kubectl apply -f cudns.yaml
run_cmd kubectl get clusteruserdefinednetwork -A -l purpose=kubecon-eu-2025-demo

header "Inspect the Layer2 CUDNs"
run_cmd kubectl get clusteruserdefinednetwork colored-enterprise -oyaml

header "Create four statefulsets one in each namespace"
run_cmd kubectl apply -f pods.yaml
sleep 3
run_cmd kubectl get pods -A -l purpose=kubecon-eu-2025-demo -owide

# PODS

# PAUSE HERE TO TALK ABOUT THE DEFAULT NETWORK A LITTLE BIT AND HOW KUBERNETES APIS ARE NOT AWARE OF MULTI-NETWORKS
# THIS IS WHAT WE SEE WHEN WE DO KUBECTL GET PODS

header "Inspect the pod app-blue-0 in blue-network"
run_cmd kubectl get pod -n blue app-blue-0 -oyaml
# SHOW THE LIVENESS PROBE SUCCEEDING ON THIS POD
run_cmd kubectl exec -it -n blue app-blue-0 -- ip a
run_cmd kubectl exec -it -n blue app-blue-0 -- ip r


header "Inspect the pods in blue-network"
# Execute kubectl command directly without run_cmd
PODINFO=$(kubectl get po -n blue -o=json)

# Process with jq
echo "$PODINFO" | jq -r '
.items[] | . as $pod | 
(.metadata.annotations["k8s.ovn.org/pod-networks"] | fromjson | to_entries[]) | 
"Pod: \($pod.metadata.name)\nNetwork: \(.key)\nRole: \(.value.role)\nIP: \(.value.ip_address)" + 
if .value.gateway_ip then "\nGateway: \(.value.gateway_ip)" else "" end +
"\nMAC: \(.value.mac_address)\nRoutes: " +
([.value.routes[] | "\(.dest) → \(.nextHop)"] | join(", ")) + "\n"'
read

# PAUSE HERE TO TALK ABOUT THE INFRA LOCKED NETWORKS ONLY BEING A THING - AN IMPLEMENTATION DETAIL TO BE ABLE TO DO KUBELET HEALTHCHECKS
# SINCE THAT USES PODIPS, AND OF COURSE IF WE EVER WANTED TO EXPOSE SOME OF THE POD PORTS AT THE DEFAULT NETWORK FOR WHATEVER REASON LIKE MONITORING THAT WOULD BE POSSIBLE

header "Connect from app-blue-0 to app-blue-1 within blue network via Primary podIP"
#run_cmd oc exec -it -n namespace-a app-a-0 -- curl 203.203.1.3:8080/hostname && echo
#run_cmd oc exec -it -n namespace-a app-a-0 -- curl 203.203.1.3:8080/clientip && echo
# Extract pod IP and remove CIDR notation
PRIMARYPODIP=$(kubectl get po -n blue -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-blue-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')

#run_cmd oc exec -it -n blue app-blue-0 -- curl --connect-timeout 4 http://${PRIMARYPODIP}:8080/hostname && echo
run_cmd kubectl exec -it -n blue app-blue-0 -- ping -w 2 -c 3 ${PRIMARYPODIP}

header "Connect from app-blue-0 to app-blue-1 within blue via Default podIP"

# Show that over default network podIPs you cannot reach the pods...
DEFAULTPODIP=$(kubectl get po -n blue -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-blue-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "infrastructure-locked") |
    .value.ip_address | 
    split("/")[0]')

run_cmd kubectl exec -it -n blue app-blue-0 -- ping -w 2 -c 3 ${DEFAULTPODIP}

header "Inspect the pod interface in green"
run_cmd kubectl get pod -n green app-green-0 -oyaml
run_cmd kubectl exec -it -n green app-green-0 -- ip a
run_cmd kubectl exec -it -n green app-green-0 -- ip r

header "Inspect the pods in network-green"
# Execute oc command directly without run_cmd
PODINFO=$(kubectl get po -n green -o=json)

# Process with jq
echo "$PODINFO" | jq -r '
.items[] | . as $pod | 
(.metadata.annotations["k8s.ovn.org/pod-networks"] | fromjson | to_entries[]) | 
"Pod: \($pod.metadata.name)\nNetwork: \(.key)\nRole: \(.value.role)\nIP: \(.value.ip_address)" + 
if .value.gateway_ip then "\nGateway: \(.value.gateway_ip)" else "" end +
"\nMAC: \(.value.mac_address)\nRoutes: " +
([.value.routes[] | "\(.dest) → \(.nextHop)"] | join(", ")) + "\n"'
read

header "Connect from app-green-0 to app-green-1 within green-network via Primary podIP"
# Extract pod IP and remove CIDR notation
PRIMARYPODIP=$(kubectl get po -n green -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-green-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')

run_cmd kubectl exec -it -n green app-green-0 -- ping -w 2 -c 3 ${PRIMARYPODIP}

header "Connect from app-green-0 to app-green-1 within green-network via Default podIP"

# Show that over default network podIPs you cannot reach the pods...
DEFAULTPODIP=$(oc get po -n green -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-green-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "infrastructure-locked") |
    .value.ip_address | 
    split("/")[0]')

run_cmd kubectl exec -it -n green app-green-0 -- ping -w 2 -c 3 ${DEFAULTPODIP}

header "Ensure there are zero (Admin)NetworkPolicies in your cluster"
run_cmd oc get anp
run_cmd oc get networkpolicies -A
run_cmd oc get banp

header "Inspect the pods in all three networks"
# Save the complex command as a variable
NETWORK_CMD='printf "%-9s %-11s %-12s %-16s\n" "PODNAME" "NAMESPACE" "NETWORK" "POD_IP" && { oc get po -n blue -o=json; oc get po -n green -o=json; oc get po -n red -o=json; oc get po -n yellow -o=json; } | jq -r '\''
.items[] | 
select(.metadata.name | startswith("app-")) |
. as $pod |
(.metadata.annotations["k8s.ovn.org/pod-networks"] | fromjson | to_entries[]) |
select(.value.role == "primary") |
[$pod.metadata.name, $pod.metadata.namespace, (.key | split("/")[1]), (.value.ip_address | split("/")[0])] |
@tsv
'\'' | column -t'

# Run it using eval since the command contains special characters
run_cmd eval "$NETWORK_CMD"

header "Connect from pod in blue to pod in green"
run_cmd kubectl exec -it -n blue app-blue-0 -- ping -w 2 -c 3 ${PRIMARYPODIP}

header "Connect from pod in red to pod in yellow"
# Extract pod IP and remove CIDR notation
PRIMARYPODIP=$(kubectl get po -n yellow -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-yellow-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')
run_cmd kubectl exec -it -n red app-red-0 -c agnhost-container-8080 -- ping -w 2 -c 3 ${PRIMARYPODIP}

header "Services... QUIZ TIME!"

# SERVICES
# ENSURE LOAD BALANCER KIND IS RUNNING
header "Start kind load balancer service"

header "Create two loadbalancer type services - one in BLUE and GREEN namespaces which expose these statefulsets"
run_cmd kubectl apply -f services.yaml

## PAUSE HERE TO EXPLAIN THAT SERVICES ARE BOUND TO THE UDNs unless exposed outside

header "List clusterIP Services across both networks"
run_cmd kubectl get svc -A -l purpose=kubecon-eu-2025-demo

header "List endpointslices across blue-network"
run_cmd kubectl get endpointslices -n blue

header "List endpointslices across green-network"
run_cmd kubectl get endpointslices -n green

header "Connect from app-blue-0 to a clusterIP blue in blue-network"
run_cmd kubectl get svc -n blue

SVCIP=$(kubectl get svc service-blue -n blue -o jsonpath='{.spec.clusterIP}')
run_cmd kubectl exec -it -n blue app-blue-0 -- curl --connect-timeout 3 http://${SVCIP}:80/hostname && echo

header "Connect from app-green-0 to a clusterIP green in green-network"
run_cmd kubectl get svc -n green

SVCIP=$(kubectl get svc service-green -n green -o jsonpath='{.spec.clusterIP}')
run_cmd kubectl exec -it -n green app-green-0 -- curl --connect-timeout 3 http://${SVCIP}:80/hostname && echo

header "Connect from app-blue-0 in blue-network to a clusterIP service-green in green-network"
run_cmd kubectl exec -it -n blue app-blue-0 -- curl --connect-timeout 3 http://${SVCIP}:80/hostname && echo

# NODEPORTS
header "Fetch the nodes in the cluster"
run_cmd kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}'

header "Connect from external client to blue network's nodeport"
SVCIP=$(kubectl get nodes ovn-worker -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
NODEPORT=$(kubectl get svc -n blue service-blue -o jsonpath='{.spec.ports[0].nodePort}')
run_cmd curl --connect-timeout 3 http://${SVCIP}:${NODEPORT}/hostname && echo

header "Connect from external client to green network's nodeport"
SVCIP=$(kubectl get nodes ovn-worker2 -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}')
NODEPORT=$(kubectl get svc -n green service-green -o jsonpath='{.spec.ports[0].nodePort}')
run_cmd curl --connect-timeout 3 http://${SVCIP}:${NODEPORT}/hostname && echo

# LOAD BALANCERS

header "Connect from external client to blue network's loadbalancer"
LBIP=$(kubectl get svc -n blue service-blue -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
run_cmd curl --connect-timeout 3 http://${LBIP}:80/hostname && echo

header "Connect from external client to green network's loadbalancer"
LBIP=$(kubectl get svc -n green service-green -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
run_cmd curl --connect-timeout 3 http://${LBIP}:80/hostname && echo


## PAUSE HERE TO EXPLAIN THAT DNS IS NOT PER NETWORK; COREDNS IS PART OF DEFAULT NETWORK
## SO EXPLAIN THAT DNS ONLY APPLIES TO K8s SERVICE and EXTERNAL DNS
header "Connect to KAPI Server from blue-network and green-network"
run_cmd kubectl exec -it -n blue app-blue-0 -- curl --connect-timeout 4 kubernetes.default.svc.cluster.local:443 && echo
run_cmd kubectl exec -it -n green app-green-0 -- curl --connect-timeout 4 kubernetes.default.svc.cluster.local:443 && echo
run_cmd kubectl exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 4 kubernetes.default.svc.cluster.local:443 && echo
run_cmd kubectl exec -it -n yellow app-yellow-0 -c agnhost-container-8080 -- curl --connect-timeout 4 kubernetes.default.svc.cluster.local:443 && echo

## EXTERNAL DNS GOOGLE.COM EGRESS/NORTH-SOUTH
header "Connect from app-blue-0 to internet"
run_cmd kubectl exec -it -n blue app-blue-0 -- ping -w 2 -c 3 8.8.8.8
header "Connect from app-green-0 to internet"
run_cmd kubectl exec -it -n green app-green-0 -- ping -w 2 -c 3 google.com

## OVERLAPPING SUBNETS
header "Create overlapping-udn and pods inside it"
run_cmd kubectl apply -f overlapping-with-blue-udn.yaml
sleep 3
run_cmd kubectl get pods -A -l purpose=kubecon-eu-2025-demo -owide

header "Inspect the pods in blue and overlapping-with-blue networks"
# Save the complex command as a variable
NETWORK_CMD='printf "%-9s %-11s %-12s %-16s\n" "PODNAME" "NAMESPACE" "NETWORK" "POD_IP" && { oc get po -n blue -o=json; oc get po -n overlapping-with-blue -o=json; } | jq -r '\''
.items[] | 
select(.metadata.name | startswith("app-")) |
. as $pod |
(.metadata.annotations["k8s.ovn.org/pod-networks"] | fromjson | to_entries[]) |
select(.value.role == "primary") |
[$pod.metadata.name, $pod.metadata.namespace, (.key | split("/")[1]), (.value.ip_address | split("/")[0])] |
@tsv
'\'' | column -t'

# Run it using eval since the command contains special characters
run_cmd eval "$NETWORK_CMD"

header "Connect from app-blue-0 to internet"
run_cmd kubectl exec -it -n blue app-blue-0 -- ping -w 2 -c 3 8.8.8.8
header "Connect from app-overlapping-blue-0 to internet"
run_cmd kubectl exec -it -n overlapping-with-blue app-overlapping-blue-0 -- ping -w 2 -c 3 8.8.8.8

## NETWORK POLICIES ARE ALSO network scoped

header "Network Policies... QUIZ TIME!"

header "Ensure there are zero NetworkPolicies in your cluster"
run_cmd oc get networkpolicies -A

header "Inspect the pods in colored-enterprise and blue-network"
# Save the complex command as a variable
NETWORK_CMD='printf "%-9s %-11s %-12s %-16s\n" "PODNAME" "NAMESPACE" "NETWORK" "POD_IP" && { oc get po -n red -o=json; oc get po -n yellow -o=json; oc get po -n blue -o=json; } | jq -r '\''
.items[] | 
select(.metadata.name | startswith("app-")) |
. as $pod |
(.metadata.annotations["k8s.ovn.org/pod-networks"] | fromjson | to_entries[]) |
select(.value.role == "primary") |
[$pod.metadata.name, $pod.metadata.namespace, (.key | split("/")[1]), (.value.ip_address | split("/")[0])] |
@tsv
'\'' | column -t'

# Run it using eval since the command contains special characters
run_cmd eval "$NETWORK_CMD"

header "Connect from app-red-0 to app-yellow-1 within colored-enterprise network via Primary podIP at 8080"
PRIMARYPODIP=$(kubectl get po -n yellow -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-yellow-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:8080/hostname && echo
header "Connect from app-red-0 to app-yellow-1 within colored-enterprise network via Primary podIP at 9090"
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:9090/hostname && echo

PRIMARYPODIP=$(kubectl get po -n blue -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-blue-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')
header "Connect from app-red-0 to app-blue-1 within colored-enterprise network via Primary podIP at 8080"
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:8080/hostname && echo

header "Create a network policy in namespace red that allows all red pods to talk to ONLY port 8080 for all primary udn pods (blue, green, yellow)"
run_cmd cat network-policy.yaml
run_cmd kubectl apply -f network-policy.yaml
run_cmd kubectl get networkpolicy -n red

PRIMARYPODIP=$(kubectl get po -n yellow -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-yellow-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')

header "Connect from app-red-0 to app-yellow-1 within colored-enterprise network via Primary podIP at 8080"
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:8080/hostname && echo

header "Connect from app-red-0 to app-yellow-1 within colored-enterprise network via Primary podIP at 9090"
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:9090/hostname && echo

PRIMARYPODIP=$(kubectl get po -n blue -o=json | jq -r '.items[] | 
    select(.metadata.name == "app-blue-1") | 
    .metadata.annotations["k8s.ovn.org/pod-networks"] | 
    fromjson | 
    to_entries[] | 
    select(.value.role == "primary") |
    .value.ip_address | 
    split("/")[0]')
header "Connect from app-red-0 to app-blue-1 within colored-enterprise network via Primary podIP at 8080"
run_cmd oc exec -it -n red app-red-0 -c agnhost-container-8080 -- curl --connect-timeout 3 ${PRIMARYPODIP}:8080/hostname && echo

## TWO BUGS TBD
# GREEN MISBEHAVES FOR KAPI/DNS --> this is fine as long as we don't delete and re-create
# NETPOL SCENARIO NOT WORKING AS EXPECTED ---> got around this bug by selecting all namespaces and using pod label selectors

## SECONDARY NETWORKS TOUCH AND LEAVE
