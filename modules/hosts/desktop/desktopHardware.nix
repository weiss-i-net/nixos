_: {
  flake.nixosModules.desktopHardware =
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
          "ahci"
          "nvme"
          "usbhid"
          "uas"
          "sd_mod"
        ];
        initrd.kernelModules = [ ];
        kernelModules = [ "kvm-amd" ];
        extraModulePackages = [ ];
      };

      # zstd:1 is the cheap end of btrfs compression (near-free on this CPU,
      # still a large win on /nix); noatime drops a write per read. Both only
      # affect data written from here on -- `btrfs filesystem defragment -r
      # -czstd <mountpoint>` rewrites what's already on disk.
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
          fsType = "btrfs";
          options = [
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/home" = {
          device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
          fsType = "btrfs";
          options = [
            "subvol=home"
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/nix" = {
          device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
          fsType = "btrfs";
          options = [
            "subvol=nix"
            "compress=zstd:1"
            "noatime"
          ];
        };

        "/boot" = {
          device = "/dev/disk/by-uuid/1C13-304B";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };

        # Windows partition (dual-boot). nofail so a NixOS boot never hangs on
        # it; uid/gid so jannik can read/write without sudo. force because
        # Windows Fast Startup/hibernation leaves the volume's dirty bit set
        # on every shutdown, which ntfs3 otherwise refuses to mount over.
        "/mnt/c" = {
          device = "/dev/disk/by-uuid/7AC64FF5C64FB065";
          fsType = "ntfs3";
          options = [
            "nofail"
            "uid=1000"
            "gid=100"
            "force"
          ];
        };

        # Second internal NTFS partition (Windows "G:"). Same dirty-bit
        # situation as /mnt/c above.
        "/mnt/g" = {
          device = "/dev/disk/by-uuid/0CDAE03DDAE02524";
          fsType = "ntfs3";
          options = [
            "nofail"
            "uid=1000"
            "gid=100"
            "force"
          ];
        };

        # 5.5TB internal HDD holding the Plex media library.
        "/mnt/plex" = {
          device = "/dev/disk/by-uuid/4CACC5F1ACC5D59C";
          fsType = "ntfs3";
          options = [ "nofail" ];
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
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      # Steam's own runtime and many Proton prefixes are still 32-bit, so the
      # 32-bit GL/Vulkan userspace has to be installed alongside the 64-bit one.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
}
