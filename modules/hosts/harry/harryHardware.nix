{ self, inputs, ... }: {
  flake.nixosModules.harryHardware =
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

      boot = {
        initrd.availableKernelModules = [
          "xhci_pci"
          "nvme"
          "usb_storage"
          "sd_mod"
        ];
        initrd.kernelModules = [ ];
        kernelModules = [ "kvm-intel" ];
        extraModulePackages = [ ];
      };

      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
        };

        "/home" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
          options = [ "subvol=home" ];
        };

        "/nix" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
          options = [ "subvol=nix" ];
        };

        "/boot" = {
          device = "/dev/disk/by-uuid/5236-B3B0";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };

        # Windows partition (dual-boot). nofail so a NixOS boot never hangs on
        # it; uid/gid so jannik can read/write without sudo.
        "/mnt/c" = {
          device = "/dev/disk/by-uuid/785A0D7B5A0D3800";
          fsType = "ntfs3";
          options = [
            "nofail"
            "uid=1000"
            "gid=100"
          ];
        };
      };

      swapDevices = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
