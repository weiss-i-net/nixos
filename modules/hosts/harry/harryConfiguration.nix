{
  self,
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.harryConfiguration = moduleWithSystem (
    { self', ... }:
    {
      config,
      pkgs,
      lib,
      ...
    }:

    {
      imports = with self.nixosModules; [
        inputs.nixos-hardware.nixosModules.microsoft-surface-common
        harryHardware
        desktop
        base
        gaming
        devel
        wslMount
        remoteBuild
      ];

      networking.hostName = "harry";

      # This Surface is slow and thermally limited, so builds go to desktop
      # whenever it's reachable on the LAN (nix falls back to building locally
      # when it isn't). Addressed by IP rather than name because the LAN has no
      # local DNS worth trusting -- keep the lease reserved on the router.
      remoteBuild.client = {
        enable = true;
        hostName = "172.16.58.56";
        hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVZzvjJ7CEXey/SJo2bbkzZsZ9JDxHLJYeTP/DXYaq+";
      };

      # The release this machine was installed at -- it pins the on-disk
      # state formats NixOS may assume, so it stays as-is across upgrades.
      system.stateVersion = "26.05";

      # Surface's high-DPI internal panel needs upscaling.
      programs.niri.package = self'.packages.myNiri.wrap {
        settings.outputs = lib.mkForce {
          "eDP-1".scale = 1.75;
        };
      };

      boot.kernelModules = [ "dw9719" ];

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 8 * 1024;
        }
      ];

      services.thermald.enable = true;

      # Battery-only concern, so it lives here rather than in the shared
      # desktop module -- there is nothing to switch profiles on a tower.
      services.power-profiles-daemon.enable = true;

      environment.systemPackages = with pkgs; [
        libcamera
        v4l-utils
      ];

      wslMount = {
        enable = true;
        vhdxPath = "/mnt/c/Users/janni/AppData/Local/Packages/46932SUSE.openSUSETumbleweed_022rs5jcyhyac/LocalState/ext4.vhdx";
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
            endpoint = "zvzhasipdh0g65fi.myfritz.net:55974"; # "vpn.jhiller.me:55974";
            persistentKeepalive = 25;
          }
        ];
      };
    }
  );
}
