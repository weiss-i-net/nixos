{ self, inputs, ... }: {
  flake.nixosModules.systemNetwork = {
    networking.networkmanager.enable = true;
  };
}
