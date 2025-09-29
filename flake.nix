{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    supportedSystems = ["x86_64-linux"];
    forAllSystems = f: nixpkgs.lib.genAttrs
      supportedSystems (system: f nixpkgs.legacyPackages.${system});
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);

    packages = forAllSystems (pkgs: let
      inherit (pkgs) lib;
      kubectl = lib.getExe pkgs.kubectl;
    in {
      default = pkgs.writeShellScriptBin "apply" ''
        # Apply Kubernetes manifests
        ${kubectl} apply -f cadvisor.daemonset.yaml
        ${kubectl} apply -f postgres.secret.yaml \
          -f postgres.configmap.yaml \
          -f postgres.volume.yaml \
          -f postgres.deployment.yaml \
          -f postgres.service.yaml

        ${kubectl} apply -f redis.configmap.yaml \
          -f redis.deployment.yaml \
          -f redis.service.yaml

        ${kubectl} apply -f poll.deployment.yaml \
          -f worker.deployment.yaml \
          -f result.deployment.yaml \
          -f poll.service.yaml \
          -f result.service.yaml \
          -f poll.ingress.yaml \
          -f result.ingress.yaml

        ${kubectl} apply -f traefik.rbac.yaml \
          -f traefik.deployment.yaml \
          -f traefik.service.yaml

        # Wait for Postgres pod to be ready
        echo "Waiting for Postgres pod to be ready..."
        while true; do
          POSTGRES_POD=$(kubectl get pods -l app=postgres -o jsonpath='{.items[0].metadata.name}')
          STATUS=$(kubectl get pod $POSTGRES_POD -o jsonpath='{.status.phase}')
          READY=$(kubectl get pod $POSTGRES_POD -o jsonpath='{.status.containerStatuses[0].ready}')
          if [[ "$STATUS" == "Running" && "$READY" == "true" ]]; then
            echo "Postgres pod $POSTGRES_POD is ready."
            break
          else
            echo "Waiting..."
            sleep 2
          fi
        done

        POSTGRES_CONTAINER=$(kubectl get pod $POSTGRES_POD -o jsonpath='{.spec.containers[0].name}')

        # Create votes table in Postgres
        echo "Creating votes table..."
        echo "CREATE TABLE votes (id text PRIMARY KEY, vote text NOT NULL);" | \
          kubectl exec -i $POSTGRES_POD -c $POSTGRES_CONTAINER -- psql -U postgres

        # Update /etc/hosts with node IPs
        NODES_IP=$(kubectl get nodes -o jsonpath='{.items[*].status.addresses[?(@.type=="ExternalIP")].address}')
        echo "$NODES_IP poll.dop.io result.dop.io" | sudo tee -a /etc/hosts

        echo "All done!"
      '';

    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          minikube
          kubectl
          (self.packages.${pkgs.system}.default)
        ];
      };
    });
  };
}
