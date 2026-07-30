{ self, inputs, ... }: {
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

      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "ahci"
        "nvme"
        "usbhid"
        "uas"
        "sd_mod"
      ];
      boot.initrd.kernelModules = [ ];
      boot.kernelModules = [ "kvm-amd" ];
      boot.extraModulePackages = [ ];

      fileSystems."/" = {
        device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
        fsType = "btrfs";
      };

      fileSystems."/home" = {
        device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
        fsType = "btrfs";
        options = [ "subvol=home" ];
      };

      fileSystems."/nix" = {
        device = "/dev/disk/by-uuid/bab85867-fd1b-4cf0-85ad-30e6ac523632";
        fsType = "btrfs";
        options = [ "subvol=nix" ];
      };

      fileSystems."/boot" = {
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
      fileSystems."/mnt/c" = {
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
      fileSystems."/mnt/g" = {
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
      fileSystems."/mnt/plex" = {
        device = "/dev/disk/by-uuid/4CACC5F1ACC5D59C";
        fsType = "ntfs3";
        options = [ "nofail" ];
      };

      swapDevices = [ ];

      nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
      hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
    };
}
