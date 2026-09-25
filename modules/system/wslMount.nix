_: {
  # Opt-in: importing this requires setting wslMount.vhdxPath.
  flake.nixosModules.wslMount =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    {
      options.wslMount.vhdxPath = lib.mkOption {
        type = lib.types.str;
        description = "Path to the WSL distro's ext4.vhdx, under the mounted Windows partition.";
      };

      config = {
        boot.kernelModules = [ "nbd" ];

        systemd.services.mnt-wsl-connect = {
          description = "Connect the WSL ext4.vhdx via qemu-nbd";
          unitConfig.RequiresMountsFor = "/mnt/c";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.qemu-utils}/bin/qemu-nbd -c /dev/nbd0 ${config.wslMount.vhdxPath}";
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
    };
}
