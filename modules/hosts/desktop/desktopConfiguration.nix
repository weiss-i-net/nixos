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
        backupMirror
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

      # This machine is echo's offsite copy. Both of echo's backup stores live
      # on the same NFS export there, so one restricted key rooted at
      # /mnt/dlink_nas covers both -- rrsync only confines to a single
      # directory, and the alternative is maintaining two keypairs to protect
      # data this host already holds a full copy of.
      #
      # Pulling rather than accepting a push is what lets this host expose
      # nothing: the previous restic REST server ran --no-auth on port 8000, so
      # anything on the home LAN could write into the repo.
      backupMirror = {
        enable = true;
        path = "/mnt/backup";

        remote = {
          host = "192.168.178.36";
          user = "jannik";
          hostKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKTNdFDUmkqJYB/P0rgDQHZaf2gv+i7xbuDYR4L8clb";
          # echo sits on the home LAN; this host only reaches it through the
          # tunnel, so a pull started before wg is up cannot resolve or connect.
          interface = "fritzbox";
        };

        mirrors = {
          # A restic repo is a directory of immutable, atomically-renamed pack
          # files, so a plain rsync gives a byte-identical replica -- no
          # re-packing, no index rebuild, and no repo password needed here.
          # rsync walks alphabetically, so data/ lands before index/ and
          # snapshots/: a run overlapping a backup on echo still yields a valid
          # repo, just missing the newest snapshot until the next run.
          restic = {
            remotePath = "echo_restic_repo";
            # restic encrypts every blob and this is a v2 repo, so the packs
            # are zstd-compressed before that too -- the bytes on the wire are
            # incompressible. --skip-compress cannot exclude them either,
            # since it keys off file extensions and pack files are named after
            # their own hash with none.
            compress = false;
            # echo's own cron fires at 04:00 and ends with restic forget
            # --prune, which deletes packs and rewrites indexes. Pulling
            # through that window risks copying a rewritten index alongside
            # packs it no longer matches, so this waits well clear of it
            # rather than racing a job whose duration scales with churn.
            onCalendar = "*-*-* 05:30:00";
          };

          # UrBackup already deduplicates via hardlinks and .directory_pool, so
          # -H is the whole point: without it this mirror inflates from 163GiB
          # to 206GiB and loses the structure UrBackup restores from. The tree
          # includes UrBackup's own nightly copy of backup_server*.db (written
          # ~03:10), which is what makes the mirror a directly usable storage
          # folder rather than something that has to be unpacked first.
          # urbackup_tmp_files is live scratch and never worth transferring.
          #
          # Staggered after the restic pull so the two do not split the
          # tunnel between them, and well before UrBackup's own backups start
          # around midday -- there is no genuinely quiet window, but this is
          # the calmest one.
          urbackup = {
            remotePath = "urbackup";
            hardLinks = true;
            excludes = [ "/urbackup_tmp_files/" ];
            onCalendar = "*-*-* 07:00:00";
          };
        };
      };

      # Not used by the mirror itself, which copies the repo without opening it.
      # This is here so `restic check` can be run against /mnt/backup/restic to
      # prove the offsite copy is actually restorable.
      sops.secrets."echo-restic-password" = { };
    }
  );
}
