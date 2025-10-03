#!/usr/bin/env bash

# Test all deployments/services by curling ClusterIP directly inside Minikube
test_deployment() {
    cat << 'EOF' > /tmp/curl_deployment.sh
for svc_info in "$@"; do
    name="${svc_info%%:*:*}"
    ip="${svc_info#*:}"; ip="${ip%%:*}"
    port="${svc_info##*:}"
    echo "Curling $name at $ip:$port"
    curl -s http://$ip:$port || echo "Failed to connect to $ip:$port"
    echo -e "\n---"
done
EOF

    # Generate list of name:ClusterIP:port triples, each quoted
    SERVICES=$(kubectl get svc -n default -o jsonpath='{range .items[*]}{"\""}{.metadata.name}:{.spec.clusterIP}:{.spec.ports[0].port}{"\" "} {end}')

    # Execute inside Minikube
    minikube ssh -- "bash -s" <<< "$(cat /tmp/curl_deployment.sh)" $SERVICES
}

# Test all services using internal DNS names (requires running inside a pod)
test_service() {
    cat << 'EOF' > /tmp/curl_service.sh
for svc_info in "$@"; do
    name="${svc_info%%:*:*}"
    namespace="${svc_info#*:}"; namespace="${namespace%%:*}"
    port="${svc_info##*:}"
    fqdn="$name.$namespace.svc.cluster.local"
    echo "Curling $name at $fqdn:$port"
    curl -s http://$fqdn:$port || echo "Failed to connect to $fqdn:$port"
    echo -e "\n---"
done
EOF

    # Generate array dynamically from Kubernetes
    mapfile -t SERVICES < <(kubectl get svc -n default -o jsonpath='{range .items[*]}{.metadata.name}:{.metadata.namespace}:{.spec.ports[0].port}{"\n"}{end}')

    POD_NAME="curltester-$(date +%s)"
    echo "Starting pod $POD_NAME to run curl tests..."
    echo "(pod will be removed automatically after tests finish)"
    echo "services to test: ${SERVICES[*]}"

    # Run inside a temporary curl pod
    kubectl run "$POD_NAME" --rm -i --image=curlimages/curl --restart=Never -- \
        sh -s -- "${SERVICES[@]}" < /tmp/curl_service.sh
}

# Dispatch subcommands
case "$1" in
    deployment) shift; test_deployment "$@" ;;
    service) shift; test_service "$@" ;;
    *) echo "Usage: $0 {deployment|service}" ;;
esac
