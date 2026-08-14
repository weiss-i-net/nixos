{
  self,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.desktopConfiguration = moduleWithSystem (
    { self', ... }:
    {
      lib,
      config,
      ...
    }:

    {
      imports = with self.nixosModules; [
        desktopHardware
        desktop
        base
        gaming
        devel
        wslMount
        remoteBuild
      ];

      networking.hostName = "desktop";

      # 16 threads and always on mains power, so this is the machine harry
      # offloads its builds to -- see remoteBuild.client on harry.
      remoteBuild.server.enable = true;

      # The release this machine was installed at -- it pins the on-disk
      # state formats NixOS may assume, so it stays as-is across upgrades.
      system.stateVersion = "26.05";

      # Acer VG271U is the higher-spec (2560x1440@144Hz) primary monitor; LG
      # IPS277 is the lower-spec (1920x1080@60Hz) secondary, placed to its
      # left per the desktop's physical desk layout. `.wrap` re-evaluates
      # myNiri's underlying module config with this override merged in
      # (same mechanism as NixOS's own module system); mkForce is needed
      # because otherwise the single-output default would just merge
      # alongside these two instead of being replaced.
      programs.niri.package = self'.packages.myNiri.wrap {
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

      # amdgpu's default "auto" fan/power behavior runs noticeably hotter and
      # louder under load than AMD's Windows driver. LACT gives a GUI+daemon
      # to set a custom fan curve/power limit (like Adrenalin does on
      # Windows) that persists across reboots. Host-specific because this is
      # the only machine with an AMD GPU -- harry's is Intel, where the LACT
      # daemon would have nothing to drive.
      services.lact.enable = true;

      # LACT can only do fan/power limit control without this; overdrive
      # mode is what unlocks clock/voltage curve tuning (amdgpu's
      # equivalent of Adrenalin's "Overdrive" tab).
      hardware.amdgpu.overdrive.enable = true;

      # The WSL2 openSUSE Tumbleweed instance stores its root filesystem as a
      # dynamically-sized VHDX (Hyper-V disk image) containing a raw,
      # unpartitioned ext4 filesystem, so it can't be listed directly in
      # fileSystems. qemu-nbd exposes it as /dev/nbd0 (a real block device
      # NixOS can then mount), which needs the Windows partition (/mnt/c,
      # see desktopHardware.nix) mounted first.
      wslMount = {
        enable = true;
        vhdxPath = "/mnt/c/Users/Jannik/AppData/Local/wsl/{541c815d-5aee-4426-9d51-93b8a5a9b4d3}/ext4.vhdx";
      };

      sops.secrets."desktop-wireguard-private-key" = { };
      sops.secrets."desktop-wireguard-psk" = { };
      networking.wg-quick.interfaces.fritzbox = {
        address = [
          "192.168.178.205/24"
          "fd00::205/64"
        ];
        dns = [
          "192.168.178.36"
          "192.168.178.1"
          "fd00::ec"
          "fd00::4a5d:35ff:fea4:ff42"
          "fritz.box"
        ];
        privateKeyFile = config.sops.secrets."desktop-wireguard-private-key".path;
        mtu = 1280;
        peers = [
          {
            publicKey = "nKFJElLkeRgS0WqYt4TONILr5qFJia1+MA+wxyJMY0E=";
            presharedKeyFile = config.sops.secrets."desktop-wireguard-psk".path;
            allowedIPs = [
              "192.168.178.0/24"
              "fd00::/64"
            ];
            endpoint = "vpn.jhiller.me:55974";
            persistentKeepalive = 25;
          }
        ];
      };
    }
  );
}
