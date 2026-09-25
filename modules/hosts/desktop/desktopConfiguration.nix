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
      pkgs,
      ...
    }:

    let
      # Pull-mirror one of echo's backup trees into /mnt/backup/<name> and keep
      # the last 14 read-only btrfs snapshots of it. Pulling rather than
      # accepting a push is what lets this host expose nothing; the previous
      # restic REST server ran --no-auth, so anything on the LAN could write to
      # the repo.
      mirror =
        {
          name,
          remotePath,
          onCalendar,
          extraFlags ? [ ],
        }:
        {
          services."backup-mirror-${name}" = {
            description = "Pull-mirror echo:${remotePath}";

            # /mnt/backup is a nofail mount, so without this a failed mount
            # leaves rsync writing hundreds of GiB into the root subvolume.
            unitConfig.RequiresMountsFor = "/mnt/backup";

            after = [
              "network-online.target"
              "wg-quick-fritzbox.service"
            ];
            wants = [ "network-online.target" ];

            path = [
              pkgs.rsync
              pkgs.openssh
              pkgs.btrfs-progs
            ];

            serviceConfig = {
              Type = "oneshot";
              # Seeding runs for hours, and every later run still traverses the
              # whole source before a byte moves.
              TimeoutStartSec = "24h";
              IOSchedulingClass = "idle";
              Nice = 10;
            };

            script = ''
              set -euo pipefail

              mirror=/mnt/backup/${name}
              snapdir=/mnt/backup/snapshots/${name}
              mkdir -p "$snapdir"

              # No --max-delete: both sources delete legitimately and in bulk, so
              # any threshold either false-trips or is too loose to catch
              # anything. The real guards are that a missing source path makes
              # rsync exit non-zero without deleting, plus the snapshot below.
              # --partial-dir because individual files here reach 64 GiB and an
              # interrupted run must resume rather than restart one from zero.
              rsync \
                --archive --numeric-ids --delete --delete-delay \
                --timeout=600 --stats --human-readable \
                --partial-dir=.rsync-partial --exclude=.rsync-partial \
                ${lib.concatStringsSep " " extraFlags} \
                -e 'ssh -i ${config.sops.secrets."backup-mirror-ssh-private-key".path} -o BatchMode=yes' \
                jannik@192.168.178.36:${remotePath}/ "$mirror/"

              # set -e means this is only reached on a clean transfer, so every
              # snapshot is a coherent point in time.
              btrfs subvolume snapshot -r "$mirror" "$snapdir/$(date -u +%Y-%m-%dT%H%M%SZ)"

              mapfile -t stale < <(find "$snapdir" -mindepth 1 -maxdepth 1 -type d | sort | head -n -14)
              if [ ''${#stale[@]} -gt 0 ]; then
                btrfs subvolume delete "''${stale[@]}"
              fi
            '';
          };

          timers."backup-mirror-${name}" = {
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnCalendar = onCalendar;
              # Not always on; a missed window should run at the next boot.
              Persistent = true;
              RandomizedDelaySec = "15m";
            };
          };
        };
    in

    {
      imports = with self.nixosModules; [
        desktopHardware
        desktop
        base
        gaming
        devel
        wslMount
      ];

      networking.hostName = "desktop";

      # 16 threads and always on mains power, so this is the machine harry
      # offloads its builds to -- see the buildMachines entry on harry.
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
          AllowUsers = [ "nixremote" ];
        };
      };

      users.groups.nixremote = { };
      users.users.nixremote = {
        isSystemUser = true;
        group = "nixremote";
        # nix runs `nix-daemon --stdio` through this account's login shell, so a
        # nologin shell leaves ssh working while every offloaded build fails.
        shell = pkgs.bashInteractive;
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3XazhBVJSxyiDfER3FjpFFt+fIYXOxz1fuF0cm0Hr8 nixremote"
        ];
      };

      # The closures a client uploads are unsigned; without this the daemon
      # refuses them and every offloaded build dies on a missing signature.
      nix.settings.trusted-users = [ "nixremote" ];

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
      wslMount.vhdxPath = "/mnt/c/Users/Jannik/AppData/Local/wsl/{541c815d-5aee-4426-9d51-93b8a5a9b4d3}/ext4.vhdx";

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

      sops.secrets."backup-mirror-ssh-private-key" = { };

      # echo is only reachable through the tunnel, so an unknown host key has to
      # be a hard failure rather than a prompt no timer can answer.
      programs.ssh.knownHosts."192.168.178.36".publicKey =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGKTNdFDUmkqJYB/P0rgDQHZaf2gv+i7xbuDYR4L8clb";

      systemd = lib.mkMerge [
        # A restic repo is a directory of immutable, atomically-renamed pack
        # files, so a plain rsync gives a byte-identical replica with no
        # re-packing and no repo password. Not compressed: the packs are
        # encrypted and already zstd'd, and --skip-compress can't exclude them
        # since it keys off extensions and packs are named after their hash.
        # Timed well clear of echo's 04:00 restic forget --prune, which rewrites
        # indexes the packs must still match.
        (mirror {
          name = "restic";
          remotePath = "echo_restic_repo";
          onCalendar = "*-*-* 05:30:00";
        })

        # UrBackup dedupes via hardlinks and .directory_pool, so --hard-links is
        # the whole point: without it this inflates from 163GiB to 206GiB and
        # loses the structure UrBackup restores from. urbackup_tmp_files is live
        # scratch. Staggered after the restic pull so the two don't split the
        # tunnel, and before UrBackup's own midday runs.
        (mirror {
          name = "urbackup";
          remotePath = "urbackup";
          onCalendar = "*-*-* 07:00:00";
          extraFlags = [
            "--hard-links"
            "--exclude=/urbackup_tmp_files/"
            "--compress"
            "--compress-choice=zstd"
            "--compress-level=3"
            "--skip-compress=vhdxz/vhdz/vhdx/hash/cbitmap/zst/gz/xz/zip/7z/jpg/png/mp4/mkv"
          ];
        })
      ];

      # Unused by the mirror, which copies the repo without opening it. Here so
      # `restic check` can prove the offsite copy is actually restorable.
      sops.secrets."echo-restic-password" = { };
    }
  );
}
