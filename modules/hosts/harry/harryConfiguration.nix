{ self, inputs, ... }: {
  flake.nixosModules.harryConfiguration =
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      imports = [
        inputs.nixos-hardware.nixosModules.microsoft-surface-common
        self.nixosModules.harryHardware
        self.nixosModules.base
      ];

      networking.hostName = "harry";

      # Surface's high-DPI internal panel needs upscaling.
      programs.niri.package = self.packages.${pkgs.stdenv.hostPlatform.system}.myNiri.wrap {
        settings.outputs = lib.mkForce {
          "eDP-1".scale = 1.75;
        };
      };

      boot.kernelModules = [
        "dw9719"
        "nbd"
      ];

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 8 * 1024;
        }
      ];

      services.thermald.enable = true;

      environment.systemPackages = with pkgs; [
        libcamera
        v4l-utils
      ];

      systemd.services.mnt-wsl-connect = {
        description = "Connect the WSL ext4.vhdx via qemu-nbd";
        unitConfig.RequiresMountsFor = "/mnt/c";
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.qemu-utils}/bin/qemu-nbd -c /dev/nbd0 /mnt/c/Users/janni/AppData/Local/Packages/46932SUSE.openSUSETumbleweed_022rs5jcyhyac/LocalState/ext4.vhdx";
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

      sops.secrets."harry-wireguard-private-key" = { };
      sops.secrets."harry-wireguard-psk" = { };

      networking.wg-quick.interfaces.fritzbox = {
        address = [
          "192.168.178.204/24"
          "fd00::204/64"
        ];
        dns = [
          "192.168.178.36"
          "192.168.178.1"
          "fd00::ec"
          "fd00::4a5d:35ff:fea4:ff42"
          "fritz.box"
        ];
        privateKeyFile = config.sops.secrets."harry-wireguard-private-key".path;
        peers = [
          {
            publicKey = "nKFJElLkeRgS0WqYt4TONILr5qFJia1+MA+wxyJMY0E=";
            presharedKeyFile = config.sops.secrets."harry-wireguard-psk".path;
            allowedIPs = [
              "192.168.178.0/24"
              "fd00::/64"
            ];
            endpoint = "vpn.jhiller.me:55974";
            persistentKeepalive = 25;
          }
        ];
      };
    };
}
