{
  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }: let
    supportedSystems = [ "x86_64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs
      supportedSystems (system: f nixpkgs.legacyPackages.${system});
  in {
    formatter = forAllSystems (pkgs: pkgs.alejandra);

    packages = forAllSystems (pkgs: {
      default = pkgs.writeShellApplication {
        name = "apply";
        runtimeInputs = [ pkgs.kubectl ];
        text = builtins.readFile ./apply.sh;
      };
      cluster = pkgs.writeShellApplication {
        name = "cluster";
        runtimeInputs = [ pkgs.kubectl pkgs.minikube pkgs.helm ];
        text = builtins.readFile ./cluster.sh;
      };
      toolchain = pkgs.writeShellApplication {
        name = "toolchain";
        runtimeInputs = [ pkgs.kubectl pkgs.minikube pkgs.helm ];
        text = "echo 'y' | ./cluster.sh \"$@\" && ./apply.sh && minikube dashboard";
      };
    });

    devShells = forAllSystems (pkgs: {
      default = pkgs.mkShell {
        packages = with pkgs; with self.packages.${pkgs.system}; [
          minikube
          kubectl
          default
          cluster
          toolchain
        ];
      };
    });
  };
}
