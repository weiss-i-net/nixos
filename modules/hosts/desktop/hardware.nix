{ self, inputs, ... }: {
  # TODO: this is a stub. Run `nixos-generate-config` on the desktop machine
  # and replace fileSystems/swapDevices/kernelModules below with its output.
  flake.nixosModules.desktopHardware =
    {
      config,
      lib,
      pkgs,
      modulesPath,
      ...
    }:

    {
      imports = [
        (modulesPath + "/installer/scan/not-detected.nix")
      ];

      boot.initrd.availableKernelModules = [ ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ ];
      boot.extraModulePackages = [ ];

      # TODO: replace with the real UUIDs from the desktop's disk layout.
      fileSystems."/" = {
        device = "/dev/disk/by-uuid/00000000-0000-0000-0000-000000000000";
        fsType = "btrfs";
      };

      fileSystems."/boot" = {
        device = "/dev/disk/by-uuid/0000-0000";
        fsType = "vfat";
        options = [
          "fmask=0077"
          "dmask=0077"
        ];
      };

      swapDevices = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      # TODO: drop this if the desktop isn't an Intel CPU.
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
