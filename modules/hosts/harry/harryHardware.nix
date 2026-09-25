_: {
  flake.nixosModules.harryHardware =
    {
      config,
      lib,
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

      # zstd:1 is near-free on this CPU and still a large win on /nix; noatime
      # drops a write per read. Both only affect data written from here on --
      # `btrfs filesystem defragment -r -czstd <mp>` rewrites what is on disk.
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
          options = [
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/home" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
          options = [
            "subvol=home"
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/nix" = {
          device = "/dev/disk/by-uuid/a02caabd-5ec7-49a1-9326-2305074db93d";
          fsType = "btrfs";
          options = [
            "subvol=nix"
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/boot" = {
          device = "/dev/disk/by-uuid/5236-B3B0";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };

        # Windows partition (dual-boot). nofail so a boot never hangs on it,
        # uid/gid for sudo-less access.
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

      # btrfs only notices bit rot when it reads a block, so cold data needs a
      # scrub to be checked at all. "/" covers the whole device.
      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = [ "/" ];
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
