{ self, ... }:
{
  flake.nixosModules.backupMirror =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.backupMirror;

      # Read by the systemd units as root, so sops-nix's root:root 0400
      # default under /run/secrets is exactly what's wanted.
      keyFile = config.sops.secrets."backup-mirror-ssh-private-key".path;

      mirrorModule = lib.types.submodule {
        options = {
          remotePath = lib.mkOption {
            type = lib.types.str;
            description = ''
              Source directory on the remote, relative to the root the
              forced rrsync command is confined to -- not an absolute path.
            '';
          };

          hardLinks = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = ''
              Preserve the source's hardlink topology (rsync -H). Only worth
              it for a tree that actually deduplicates that way; on one that
              does not it just costs a table of every file in the transfer.
            '';
          };

          excludes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Extra rsync --exclude patterns for this mirror.";
          };

          compress = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = ''
              Compress the transfer. Turn it off for a source whose bytes are
              already compressed or encrypted throughout: --skip-compress
              cannot rescue those, because it matches on file extension and
              content-addressed names do not have one.
            '';
          };

          snapshotCount = lib.mkOption {
            type = lib.types.ints.positive;
            default = 14;
            description = ''
              Read-only snapshots to retain. These are the only undo for a
              deletion propagating from the source, so err generous: btrfs
              snapshots of an append-mostly tree pin only the extents that
              later get removed, which is nearly free.
            '';
          };

          onCalendar = lib.mkOption {
            type = lib.types.str;
            description = "systemd OnCalendar expression for this mirror's timer.";
          };
        };
      };

      mirrorService = name: mirror: {
        description = "Pull-mirror ${cfg.remote.host}:${mirror.remotePath}";

        # The mount is nofail, so without this a failed mount would leave rsync
        # happily writing hundreds of GiB into the root subvolume instead.
        unitConfig.RequiresMountsFor = cfg.path;

        after = [
          "network-online.target"
          "wg-quick-${cfg.remote.interface}.service"
        ];
        wants = [ "network-online.target" ];

        path = [
          pkgs.rsync
          pkgs.openssh
          pkgs.btrfs-progs
        ];

        serviceConfig = {
          Type = "oneshot";
          # Only root can restore the source's uid/gid on the mirror, which is
          # what --numeric-ids exists to do.
          User = "root";
          # Seeding runs for hours over the tunnel, and every later run still
          # pays a full traversal of the source before a single byte moves.
          TimeoutStartSec = "24h";
          # This is a background copy of cold data; it should never be the
          # reason something interactive stutters.
          IOSchedulingClass = "idle";
          Nice = 10;
        };

        script =
          let
            flags = [
              "--archive"
              "--numeric-ids"
            ]
            ++ lib.optional mirror.hardLinks "--hard-links"
            ++ [
              "--delete"
              # With -H, deleting as we go can remove a file that is still a
              # live hardlink target later in the run; deferring to the end
              # avoids re-transferring it.
              "--delete-delay"
              # Individual files here reach 64 GiB. An interrupted run must
              # resume rather than restart one from zero over this link.
              "--partial-dir=.rsync-partial"
              "--timeout=600"
              "--exclude=.rsync-partial"
            ]
            ++ lib.optionals mirror.compress [
              "--compress"
              "--compress-choice=zstd"
              "--compress-level=3"
              # The bulk items that are already compressed -- UrBackup's
              # .vhdxz images and the hash/bitmap sidecars beside them --
              # would otherwise be fed through zstd for nothing. What is left
              # is the client file backups, which are ordinary documents and
              # do compress.
              "--skip-compress=vhdxz/vhdz/vhdx/hash/cbitmap/zst/gz/xz/zip/7z/jpg/png/mp4/mkv"
            ]
            ++ map (p: "--exclude=${p}") mirror.excludes
            ++ [
              "--stats"
              "--human-readable"
              "-e"
              "'ssh -i ${keyFile} -o BatchMode=yes'"
            ];
          in
          ''
            set -euo pipefail

            mirror=${lib.escapeShellArg "${cfg.path}/${name}"}
            snapdir=${lib.escapeShellArg "${cfg.path}/snapshots/${name}"}
            mkdir -p "$snapdir"

            # Deliberately no --max-delete: both sources delete legitimately and
            # in bulk (UrBackup retiring whole backup directories, restic prune
            # dropping packs), so any threshold either false-trips or is too
            # loose to catch anything. The guards that do work are that a
            # missing source path makes rsync exit non-zero without deleting
            # anything, and the read-only snapshot taken below.
            rsync \
              ${lib.concatStringsSep " \\\n  " flags} \
              ${lib.escapeShellArg "${cfg.remote.user}@${cfg.remote.host}:${mirror.remotePath}/"} \
              "$mirror/"

            # set -e means we only get here on a clean transfer, so every
            # snapshot is a coherent point-in-time copy rather than a
            # half-applied one.
            btrfs subvolume snapshot -r "$mirror" "$snapdir/$(date -u +%Y-%m-%dT%H%M%SZ)"

            # Timestamp names sort lexicographically, so plain sort is newest-last.
            mapfile -t stale < <(
              find "$snapdir" -mindepth 1 -maxdepth 1 -type d \
                | sort \
                | head -n "-${toString mirror.snapshotCount}"
            )
            if [ ''${#stale[@]} -gt 0 ]; then
              btrfs subvolume delete "''${stale[@]}"
            fi
          '';
      };

      mirrorTimer = _name: mirror: {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = mirror.onCalendar;
          # This host is not always on; a missed window should run at the next
          # boot rather than silently skip a day.
          Persistent = true;
          RandomizedDelaySec = "15m";
        };
      };
    in
    {
      imports = with self.nixosModules; [
        secrets
      ];

      options.backupMirror = {
        enable = lib.mkEnableOption "pulling remote backup trees into local btrfs subvolumes over ssh";

        path = lib.mkOption {
          type = lib.types.str;
          description = ''
            btrfs mount point holding one subvolume per mirror plus a
            snapshots/ directory. The parent is what gets mounted rather than
            the mirrors themselves, so the read-only snapshots sit on the same
            filesystem but outside any rsync --delete target.
          '';
        };

        remote = {
          host = lib.mkOption {
            type = lib.types.str;
            description = "Address of the machine holding the backup trees.";
          };

          user = lib.mkOption {
            type = lib.types.str;
            description = "Account to log in as; its authorized_keys entry is what confines the transfer.";
          };

          hostKey = lib.mkOption {
            type = lib.types.str;
            description = "The remote's ssh host public key, pinned in the system known_hosts.";
          };

          interface = lib.mkOption {
            type = lib.types.str;
            description = "wg-quick interface the remote is only reachable over, ordered before each pull.";
          };
        };

        mirrors = lib.mkOption {
          type = lib.types.attrsOf mirrorModule;
          default = { };
          description = ''
            One entry per mirrored tree. The attribute name is used for the
            local subvolume, the snapshot directory and the unit names.
          '';
        };
      };

      config = lib.mkIf cfg.enable {
        sops.secrets."backup-mirror-ssh-private-key" = { };

        # The timers connect non-interactively, so an unknown host key has to be
        # a hard failure rather than a prompt nobody is there to answer.
        programs.ssh.knownHosts.${cfg.remote.host}.publicKey = cfg.remote.hostKey;

        systemd.services = lib.mapAttrs' (
          name: mirror: lib.nameValuePair "backup-mirror-${name}" (mirrorService name mirror)
        ) cfg.mirrors;

        systemd.timers = lib.mapAttrs' (
          name: mirror: lib.nameValuePair "backup-mirror-${name}" (mirrorTimer name mirror)
        ) cfg.mirrors;
      };
    };
}
