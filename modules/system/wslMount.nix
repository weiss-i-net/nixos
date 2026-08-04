{ ... }:
{
  flake.nixosModules.wslMount =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.wslMount;
    in
    {
      options.wslMount = {
        enable = lib.mkEnableOption "mounting a WSL distro's ext4.vhdx at /mnt/wsl via qemu-nbd";
        vhdxPath = lib.mkOption {
          type = lib.types.str;
          description = "Path to the WSL distro's ext4.vhdx (under the mounted Windows partition).";
        };
      };

      config = lib.mkIf cfg.enable {
        boot.kernelModules = [ "nbd" ];

        systemd.services.mnt-wsl-connect = {
          description = "Connect the WSL ext4.vhdx via qemu-nbd";
          unitConfig.RequiresMountsFor = "/mnt/c";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${pkgs.qemu-utils}/bin/qemu-nbd -c /dev/nbd0 ${cfg.vhdxPath}";
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
