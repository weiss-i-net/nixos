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

      # zstd:1 is near-free on this CPU and still a large win on /nix; noatime
      # drops a write per read. Both only affect data written from here on --
      # `btrfs filesystem defragment -r -czstd <mp>` rewrites what is on disk.
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

        # Windows partition (dual-boot). nofail so a boot never hangs on it,
        # uid/gid for sudo-less access, force because Fast Startup leaves the
        # dirty bit set on every shutdown and ntfs3 refuses to mount over that.
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

        # 5.5TB HDD with the Plex library; the other NTFS volume Windows shares,
        # so same options for the same reasons as /mnt/c.
        "/mnt/plex" = {
          device = "/dev/disk/by-uuid/4CACC5F1ACC5D59C";
          fsType = "ntfs3";
          options = [
            "nofail"
            "uid=1000"
            "gid=100"
            "force"
          ];
        };

        # Offsite copies of echo's backup stores (see the mirror timers in
        # desktopConfiguration.nix). The parent is mounted rather than the
        # individual mirrors, so the read-only snapshots under snapshots/ sit on
        # the same filesystem but outside every rsync --delete target. The
        # subvolumes must exist first; "/" here is subvolid=5, the btrfs top
        # level, so they are created directly as /backup and /backup/<name>.
        "/mnt/backup" = {
          device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
          fsType = "btrfs";
          options = [
            "subvol=backup"
            "compress=zstd:1"
            "noatime"
            "nofail"
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
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
      # Steam's runtime and many Proton prefixes are 32-bit. programs.steam sets
      # these too, but graphics is a property of the machine, not of a bundle.
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
}
