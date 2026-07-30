{ self, inputs, ... }: {
  flake.nixosModules.desktopConfiguration =
    { config, pkgs, ... }:

    {
      imports = [
        self.nixosModules.desktopHardware
        self.nixosModules.base
        self.nixosModules.gaming
      ];

      networking.hostName = "desktop";

      # Two-monitor desk setup; see the outputs override in this file's
      # perSystem block below (settings/keybinds themselves live in
      # modules/features/niri/default.nix, shared with all hosts).
      programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiriDesktop;

      # Provides /dev/nbd*, used below to expose the WSL ext4.vhdx as a
      # block device (qemu-nbd can't create the node itself).
      boot.kernelModules = [ "nbd" ];

      # The WSL2 openSUSE Tumbleweed instance stores its root filesystem as a
      # dynamically-sized VHDX (Hyper-V disk image) containing a raw,
      # unpartitioned ext4 filesystem, so it can't be listed directly in
      # fileSystems. qemu-nbd exposes it as /dev/nbd0 (a real block device
      # NixOS can then mount), which needs the Windows partition (/mnt/c,
      # see hardware.nix) mounted first.
      systemd.services.mnt-wsl-connect = {
        description = "Connect the WSL ext4.vhdx via qemu-nbd";
        unitConfig.RequiresMountsFor = "/mnt/c";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.qemu-utils}/bin/qemu-nbd -c /dev/nbd0 /mnt/c/Users/Jannik/AppData/Local/Packages/46932SUSE.openSUSETumbleweed_022rs5jcyhyac/LocalState/ext4.vhdx";
          ExecStop = "${pkgs.qemu-utils}/bin/qemu-nbd -d /dev/nbd0";
        };
      };

      fileSystems."/mnt/wsl" = {
        device = "/dev/nbd0";
        fsType = "ext4";
        options = [
          "nofail"
          "x-systemd.requires=mnt-wsl-connect.service"
        ];
      };
    };

  perSystem =
    {
      pkgs,
      lib,
      self',
      ...
    }:
    {
      # Acer VG271U is the higher-spec (2560x1440@144Hz) primary monitor; LG
      # IPS277 is the lower-spec (1920x1080@60Hz) secondary, placed to its
      # left per the desktop's physical desk layout.
      packages.myNiriDesktop = self.lib.mkNiriPackage {
        inherit pkgs lib self';
        outputs = {
          "HDMI-A-1" = {
            scale = 1;
            position = _: {
              props = {
                x = 0;
                y = 0;
              };
            };
          };
          "DP-2" = {
            scale = 1;
            position = _: {
              props = {
                x = 1920;
                y = 0;
              };
            };
          };
        };
      };
    };
}
