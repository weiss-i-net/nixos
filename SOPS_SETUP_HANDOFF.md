# sops-nix setup — handoff to harry

Delete this file once the setup below is finished; it's a working note, not
permanent project docs.

## Context

Setting up sops-nix in this NixOS flake to manage three secrets: the
`jannik` user's login password, `jannik`'s personal SSH key
(`~/.ssh/id_ed25519`, currently only on `desktop`), and `harry`'s WireGuard
key+PSK (currently plaintext at `/etc/wireguard/harry-fritzbox.key`/`.psk`).

**Sync first.** The changes below were made on `desktop` and are still
uncommitted there (`jj status` shows them as working-copy changes, not
pushed to `origin` — `github.com/weiss-i-net/nixos`). Before doing anything
on `harry`, make sure its checkout actually has these files (check for
`modules/system/secrets/default.nix`). If not, push from `desktop` and pull
here first.

## Already done (from desktop)

- `flake.nix` — added a `sops-nix` input (`github:Mic92/sops-nix`, follows
  nixpkgs).
- `modules/system/secrets/default.nix` (new) — defines
  `flake.nixosModules.systemSecrets`: imports
  `inputs.sops-nix.nixosModules.sops`, sets
  `sops.defaultSopsFile = ./secrets.yaml` and
  `sops.age.keyFile = "/var/lib/sops-nix/key.txt"`, declares
  `sops.secrets."jannik-password"` (`neededForUsers = true`) and
  `sops.secrets."jannik-ssh-private-key"` (`path = "/home/jannik/.ssh/id_ed25519"`,
  owner `jannik`, mode `0600`), plus a `systemd.tmpfiles.rules` entry to
  create `~/.ssh` with `0700`.
- `modules/attrs/base/default.nix` — imports `systemSecrets`, sets
  `users.users.jannik.hashedPasswordFile = config.sops.secrets."jannik-password".path`.
- `modules/hosts/harry/harryConfiguration.nix` — declares
  `sops.secrets."harry-wireguard-private-key"` and `"harry-wireguard-psk"`
  (default path, root-only), and points the `wg-quick` interface's
  `privateKeyFile`/`presharedKeyFile` at them instead of
  `/etc/wireguard/...`.
- `modules/devshell.nix` — added `pkgs.sops` and `pkgs.age` to the dev
  shell.

## Design decisions to preserve

- One shared `modules/system/secrets/secrets.yaml`, encrypted for exactly
  three age recipients: an "admin" key (mine, on `desktop`, at
  `~/.config/sops/age/keys.txt`), `desktop`'s host key, and `harry`'s host
  key. This lets either host decrypt at boot, and lets the admin key edit
  secrets from a dev checkout without needing to be on either machine.
- Known public keys so far:
  - admin: `age1djs6s5qk50mzl4zww77xeqx2k8va8h5trc729w23mylrdpfa5d0q5pakxr`
  - desktop: `age1d2prhp5h9nk9xhv6e5mh76adwga4hk90f4j0lavlvaq9axs3l48sx5v388`
  - harry: not yet generated (or possibly already started — check for
    `/tmp/harry-sops-key.txt` from an earlier instruction).
- Per-host decryption key lives at `/var/lib/sops-nix/key.txt` (root-owned,
  `0600`, **not** in git) — standard sops-nix bootstrap step, done once per
  machine.

## Remaining steps on harry

1. Generate harry's host age keypair if not already done (check
   `/tmp/harry-sops-key.txt` first):
   `nix shell nixpkgs#age -c age-keygen -o /tmp/harry-sops-key.txt`.
2. `sudo mkdir -p /var/lib/sops-nix && sudo mv /tmp/harry-sops-key.txt /var/lib/sops-nix/key.txt && sudo chmod 600 /var/lib/sops-nix/key.txt`
   (needs the user's sudo password — run interactively).
3. Get the public key:
   `nix shell nixpkgs#age -c age-keygen -y /var/lib/sops-nix/key.txt`.
4. Write `.sops.yaml` at the repo root with all three keys as recipients
   for `modules/system/secrets/secrets.yaml` (creation_rules, path_regex
   matching that one file).
5. Create the encrypted file: `sops modules/system/secrets/secrets.yaml` —
   **run this yourself interactively in your own terminal, not through the
   assistant's tool calls**, so secret plaintext never passes through the
   conversation. It opens `$EDITOR`; fill in as a flat YAML map with these
   exact keys:
   - `jannik-password`: a password hash, e.g. from `mkpasswd -m sha-512`
     (same password as desktop, per the user).
   - `jannik-ssh-private-key`: leave a placeholder for now (e.g.
     `TODO-fill-from-desktop`) — the real key only exists on `desktop`.
   - `harry-wireguard-private-key`: contents of
     `/etc/wireguard/harry-fritzbox.key`.
   - `harry-wireguard-psk`: contents of `/etc/wireguard/harry-fritzbox.psk`.
6. Verify: `nix flake show .` then `nixos-rebuild build --flake .#harry`
   (this will also update `flake.lock` for the new `sops-nix` input —
   expected).
7. Do **not** delete the old `/etc/wireguard/harry-fritzbox.key`/`.psk` yet
   — only after a real `nixos-rebuild switch` on `harry` confirms the
   tunnel still comes up via the sops-managed path.

## What still needs to happen back on desktop afterward

Once `.sops.yaml` includes harry's real public key, re-run
`sops updatekeys modules/system/secrets/secrets.yaml` on desktop (or just
re-save it) if it was re-keyed, and fill in the real
`jannik-ssh-private-key` value there via
`sops modules/system/secrets/secrets.yaml` (interactively, using the admin
key already at `~/.config/sops/age/keys.txt`) with the actual contents of
`~/.ssh/id_ed25519`. Then verify both hosts build.
