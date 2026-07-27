{ self, inputs, ... }: {
  flake.nixosModules.harryConfiguration =
    { config, pkgs, ... }:

    {
      imports = [
        inputs.nixos-hardware.nixosModules.microsoft-surface-common
        self.nixosModules.harryHardware
        self.nixosModules.common
      ];

      networking.hostName = "harry"; # Define your hostname.

      # The IPU3 CIO2 driver's fwnode async notifier completion is recursive:
      # it also waits on ov8865's ancillary VCM (autofocus motor) sub-notifier,
      # which never completes because dw9719 has no ACPI/i2c modalias (only
      # device-tree `of:` aliases), so udev never auto-loads it for the
      # software-node-instantiated VCM device. That one unsatisfied ancillary
      # connection silently blocks CIO2's media-graph links for all 3 sensors,
      # not just the rear camera (confirmed live via media-ctl -p and kernel
      # dynamic debug on v4l2_async/ipu3_cio2/ipu_bridge). Force it to load.
      boot.kernelModules = [ "dw9719" ];

      swapDevices = [
        {
          device = "/var/lib/swapfile";
          size = 8 * 1024;
        }
      ];

      # The EC drives the fan off Intel DPTF thermal trip points; thermald's
      # --adaptive mode loads the OEM DPTF tables from ACPI so the fan
      # actually idles instead of running constantly (no direct PWM control
      # exists for this hardware).
      services.thermald.enable = true;

      environment.systemPackages = with pkgs; [
        # `cam`/`media-ctl`/`v4l2-ctl` for verifying the IPU3 camera stack
        # (see the dw9719 force-load above).
        libcamera
        v4l-utils
      ];

      # Keys live outside the repo (/etc/wireguard, not in the nix store) so
      # they never end up in git history.
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
        privateKeyFile = "/etc/wireguard/harry-fritzbox.key";
        peers = [
          {
            publicKey = "nKFJElLkeRgS0WqYt4TONILr5qFJia1+MA+wxyJMY0E=";
            presharedKeyFile = "/etc/wireguard/harry-fritzbox.psk";
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
