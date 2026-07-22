{ self, inputs, ... }: {
  flake.nixosConfigurations.harry = inputs.nixpkgs.lib.nixosSystem {
    modules = [
      self.nixosModules.harryConfiguration
    ];
  };
}
