{ self, inputs, ... }: {
  flake.nixosModules.desktopConfiguration =
    { config, pkgs, ... }:

    {
      imports = [
        self.nixosModules.desktopHardware
        self.nixosModules.common
      ];

      networking.hostName = "desktop";
    };
}
