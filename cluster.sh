#!/usr/bin/env bash
# This script use minikube and setup all necessary components to run the cluster locally.

set -euo pipefail

NODES=3

# Check if a cluster already exists
if minikube status >/dev/null 2>&1; then
  echo "A Minikube cluster already exists."
  read -rp "Do you want to delete the old cluster and start fresh? (y/n) " ans
  case "$ans" in
    y|Y)
      echo "Deleting old Minikube cluster..."
      minikube delete "$@"
      ;;
    *)
      echo "Keeping existing cluster. Exiting."
      exit 0
      ;;
  esac
fi

echo "Starting Minikube with $NODES nodes..."
minikube start --nodes "$NODES"

echo "Ensuring Postgres volume directories exist on all nodes..."
echo "Creating dirs on minikube..."
minikube ssh -n "minikube" "sudo mkdir -p /var/lib/postgresql/data /var/run/postgresql"
for i in $(seq 2 "$NODES"); do
  node="minikube-m0$((i))"
  echo "Creating dirs on $node..."
  minikube ssh -n "$node" "sudo mkdir -p /var/lib/postgresql/data && sudo chown -R docker:docker /var/lib/postgresql"
done

echo "Cluster is ready with Postgres volume directories created!"
