# THIS CODE IS UNVERIFIED
{
  description = "KVM-backed NixOS VM for isolated CLI agent execution on Baguette";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      nixos = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [ ./vm/configuration.nix ];
      };
    in
    {
      # Build the VM run script: nix build .#agent-vm
      packages.${system}.agent-vm = nixos.config.system.build.vm;
      packages.${system}.default = self.packages.${system}.agent-vm;

      # NixOS configuration for inspection/testing
      nixosConfigurations.agent-vm = nixos;
    };
}
