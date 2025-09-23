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
