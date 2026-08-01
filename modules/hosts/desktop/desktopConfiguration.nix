{ self, inputs, ... }: {
  flake.nixosModules.desktopConfiguration =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      imports = [
        self.nixosModules.desktopHardware
        self.nixosModules.base
        self.nixosModules.gaming
      ];

      networking.hostName = "desktop";

      # Acer VG271U is the higher-spec (2560x1440@144Hz) primary monitor; LG
      # IPS277 is the lower-spec (1920x1080@60Hz) secondary, placed to its
      # left per the desktop's physical desk layout. `.wrap` re-evaluates
      # myNiri's underlying module config with this override merged in
      # (same mechanism as NixOS's own module system); mkForce is needed
      # because otherwise the single-output default would just merge
      # alongside these two instead of being replaced.
      programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri.wrap {
        settings.outputs = lib.mkForce {
          "HDMI-A-1" = {
            scale = 1;
            position = _: {
              props = {
                x = 0;
                y = 180;
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
          ExecStart = "${pkgs.qemu-utils}/bin/qemu-nbd -c /dev/nbd0 /mnt/c/Users/Jannik/AppData/Local/wsl/{541c815d-5aee-4426-9d51-93b8a5a9b4d3}/ext4.vhdx";
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
}
