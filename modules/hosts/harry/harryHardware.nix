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

      # zstd:1 is the cheap end of btrfs compression (near-free on this CPU,
      # still a large win on /nix); noatime drops a write per read. Both only
      # affect data written from here on -- `btrfs filesystem defragment -r
      # -czstd <mountpoint>` rewrites what's already on disk.
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

      # Scrubbing "/" covers the whole device, subvolumes included -- btrfs
      # only detects bit rot when it reads a block, so without this a stale
      # corruption in cold data goes unnoticed until something needs it.
      services.btrfs.autoScrub = {
        enable = true;
        interval = "monthly";
        fileSystems = [ "/" ];
      };

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
