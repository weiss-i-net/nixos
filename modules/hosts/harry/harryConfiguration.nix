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
      ];

      networking.hostName = "harry";

      # Slow and thermally limited, so builds go to desktop when it's reachable
      # (nix falls back to building locally when it isn't). By IP because the
      # LAN has no DNS worth trusting -- keep the lease reserved on the router.
      nix = {
        distributedBuilds = true;
        buildMachines = [
          {
            hostName = "172.16.58.56";
            sshUser = "nixremote";
            sshKey = config.sops.secrets."nixremote-ssh-private-key".path;
            systems = [ "x86_64-linux" ];
            protocol = "ssh-ng";
            maxJobs = 8;
            # Above 1 makes nix prefer the builder over this host's own slot.
            speedFactor = 4;
            supportedFeatures = [
              "nixos-test"
              "benchmark"
              "big-parallel"
              "kvm"
            ];
          }
        ];
        # Let the builder fetch substitutes rather than routing them via here.
        settings.builders-use-substitutes = true;
      };

      sops.secrets."nixremote-ssh-private-key" = { };

      # The daemon connects non-interactively, so an unknown host key has to fail
      # rather than prompt.
      programs.ssh.knownHosts."172.16.58.56".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGVZzvjJ7CEXey/SJo2bbkzZsZ9JDxHLJYeTP/DXYaq+";

      # The release this machine was installed at; never bumped.
      system.stateVersion = "26.05";

      # Surface's high-DPI internal panel needs upscaling.
      programs.niri.package = self'.packages.myNiri.wrap {
        settings.outputs = lib.mkForce {
          "eDP-1".scale = 1.75;
        };
      };

      # The IPU3 camera's lens-focus VCM driver isn't autoloaded.
      boot.kernelModules = [ "dw9719" ];

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 8 * 1024;
        }
      ];

      services.thermald.enable = true;

      # Battery-only, so not in the shared desktop module.
      services.power-profiles-daemon.enable = true;

      environment.systemPackages = with pkgs; [
        libcamera
        v4l-utils
      ];

      wslMount.vhdxPath = "/mnt/c/Users/janni/AppData/Local/Packages/46932SUSE.openSUSETumbleweed_022rs5jcyhyac/LocalState/ext4.vhdx";

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
        mtu = 1280;
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

      # wg-quick resolves the endpoint hostname once, when the unit starts, and
      # NetworkManager reaches network-online.target before /etc/resolv.conf has
      # a usable nameserver -- so at boot this fails instantly with "Name or
      # service not known" and, being a oneshot, stays down. Retry until DNS
      # answers; no start limit, so it is never permanently down.
      systemd.services.wg-quick-fritzbox = {
        unitConfig.StartLimitIntervalSec = 0;
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 10;
        };
      };
    }
  );
}
