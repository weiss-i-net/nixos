# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Version control: jj, not git

This repo is a colocated `jj`/`git` repo (both `.jj/` and `.git/` exist). Use Jujutsu (`jj`) commands, not `git` — the `jj-vcs` skill auto-activates for VCS operations and covers the workflow (`jj status`, `jj describe -m`, `jj new`, etc.). The one thing worth knowing that the skill has no way to infer: the `.git` directory here exists only for jj colocation and flake `git+file` resolution, not for direct use — don't run `git commit`/`git add` directly, operate through `jj`.

## Commands

- `nix flake show .` — list all outputs (hosts, packages, formatter) and sanity-check that the flake evaluates.
- `nixos-rebuild build --flake .#<host>` — build a host's system closure without switching (safest way to check a change compiles). Hosts: `desktop`, `harry`.
- `sudo nixos-rebuild switch --flake .#<host>` — apply on the local machine (only run this if explicitly asked to; it's a live-system change).
- `nix build .#<packageName>` — build a single wrapped package (e.g. `nix build .#myNeovim`) to check just that module.
- `nix fmt` — format the tree with `nixfmt-tree` (configured in `modules/formatter.nix`).
- There is no separate lint/test suite; `nix flake show` and `nixos-rebuild build` are the correctness checks.
- `modules/system/secrets/secrets.yaml` is sops-nix encrypted; edit it with `sops modules/system/secrets/secrets.yaml` (decrypts using the age key at `/var/lib/sops-nix/key.txt` on target hosts). The devShell (`nix develop`) provides `sops` and `age`.

## Architecture

### Dendritic pattern via import-tree + flake-parts

`flake.nix` is intentionally minimal: it declares inputs and calls `flake-parts.lib.mkFlake` with a single module list produced by `inputs.import-tree ./modules`. `import-tree` recursively imports every `.nix` file under `modules/` as a flake-parts module — there is no manual list of imports to maintain. **Any new `.nix` file dropped anywhere under `modules/` is automatically wired in**; naming/location controls organization only, not whether it's loaded.

Each module file is a self-contained flake-parts module (a function of `{ self, inputs, ... }` or similar) that contributes fragments to the flake's output attrsets — typically `flake.nixosModules.<name>`, `flake.nixosConfigurations.<name>`, or `perSystem` outputs like `packages.<name>`/`formatter`. Because every file can contribute to any output, host configs, feature modules, and package definitions are all peers in the same tree rather than being layered through a central `default.nix`. Read a file's `config`/`flake`/`perSystem` keys to know what it produces — don't assume based on its path.

`modules/parts.nix` sets `systems = [ "x86_64-linux" "aarch64-linux" ]`, which is what drives `perSystem` evaluation across both architectures.

### Module categories

`modules/` splits into four top-level categories, each with a distinct role:
- `features/` — one subfolder per wrapped app/binary (e.g. `neovim`, `kitty`, `tmux`).
- `attrs/` — attributes composed from other modules; no new features/binaries defined here, just bundling.
- `system/` — basic system config with no binaries of its own; not meant to be used standalone (network, audio, etc.).
- `hosts/` — per-machine presets; output names match the subfolder names (`nixosConfigurations.desktop`, `.harry`).

This is what determines where a new module belongs: a wrapped program goes in `features/`, a reusable bundle of other modules goes in `attrs/`, binary-less system config goes in `system/`, and machine-specific config goes in `hosts/`.

### Hosts

Each host lives in `modules/hosts/<name>/` with three files:
- `hardware.nix` — machine-specific hardware config (normally hardware-scan output, hand-edited for this host), defining `flake.nixosModules.<name>Hardware`.
- `<name>Configuration.nix` — defines `flake.nixosModules.<name>Configuration`, importing that host's hardware module plus `self.nixosModules.base` (and, for `desktop`, `self.nixosModules.gaming`), and setting host-specific options (e.g. `networking.hostName`, kernel workarounds, host-only packages/secrets).
- `default.nix` — defines `flake.nixosConfigurations.<name>` via `inputs.nixpkgs.lib.nixosSystem`, importing only `self.nixosModules.<name>Configuration`.

`modules/attrs/base/default.nix` defines `flake.nixosModules.base`, imported by every host. It pulls together the shared `system/*` modules below plus `self.nixosModules.niri`, and defines the `jannik` user (shell, sops-managed `hashedPasswordFile`, per-user packages) along with a handful of system-wide packages.

`modules/attrs/gaming/default.nix` defines `flake.nixosModules.gaming`, an opt-in bundle (Steam, gamemode, gamescope, the LACT fan-control daemon) currently only imported by `desktop`, not `harry`.

`modules/system/` splits what used to be a single `common.nix` into one file per concern, each contributing its own `flake.nixosModules.system<Topic>` fragment that `base` imports:
- `core/` — boot loader, locale/timezone, fish, nix settings (flakes, gc), zram, `system.stateVersion`.
- `audio/` — pipewire + rtkit.
- `desktop/` — greetd+niri session, xkb layout, fonts, bluetooth, printing, upower, cursor env vars.
- `network/` — NetworkManager.
- `secrets/` — sops-nix wiring (`sops.defaultSopsFile`/`age.keyFile`) plus the `secrets.yaml` it decrypts; declares the `jannik-password` (used for the user's `hashedPasswordFile`) and `jannik-ssh-private-key` secrets. Per-host secrets (e.g. `harry`'s WireGuard keys) are declared directly in that host's `<name>Configuration.nix` instead.

Host-specific quirks (e.g. the `dw9719` kernel module workaround on `harry` for IPU3 camera bring-up, or `thermald` for fan control) stay in that host's `<name>Configuration.nix` with a comment explaining the underlying hardware issue — keep that pattern (explain *why*, not what) for any new hardware workaround.

Adding a host means adding a new `modules/hosts/<name>/` directory following this same three-file shape; nothing elsewhere needs to change since `import-tree` picks it up automatically.

### wrapper-modules for user-facing programs

`modules/features/<program>/default.nix` (one directory per program, e.g. `neovim/`, `kitty/`, `tmux/`, `jujutsu/`, `niri/`, `noctalia/`) mostly wrap TUI/GUI programs using the `wrapper-modules` flake input (`inputs.wrapper-modules.wrappers.<program>.wrap { inherit pkgs; settings = { ... }; }`), exposed as `perSystem.packages.my<Program>` (e.g. `myNeovim`, `myKitty`, `myTmux`, `myJujutsu`, `myNiri`, `myNoctalia`). This generates the program's config file(s) from Nix attrsets/strings instead of hand-written dotfiles — the wrapped package embeds its config, so there is no `~/.config/<program>` to edit by hand. Some feature directories carry extra non-Nix support files alongside `default.nix` (e.g. `neovim/astronvim-init.lua` and `neovim/bridge-plugin/` for its Lua plugin bridge, `noctalia/noctalia.json` read via `builtins.fromJSON`) — the same rule applies to those: edit and rebuild, don't hand-patch generated output. **To change a program's behavior, edit its `settings` (or `configBefore`/`configAfter` for raw config text, as in `tmux/default.nix`) in the corresponding `modules/features/<program>/default.nix` file and rebuild** — do not edit generated config files directly (see the intentional "config is managed by Nix" tmux binding in `modules/features/tmux/default.nix`).

`niri/default.nix` is the one feature module that also produces a `flake.nixosModules.niri` (a real NixOS module enabling `programs.niri` system-wide with the wrapped package), in addition to its `perSystem.packages.myNiri`. That NixOS module is imported by `modules/attrs/base/default.nix`. Other feature modules only produce `perSystem` packages, which get pulled into the user's package list in `base`'s `users.users."jannik".packages`.

Wrapped packages can reference each other across modules via `self'.packages.<name>` inside `perSystem` (e.g. `niri/default.nix` uses `self'.packages.myKitty` and `self'.packages.myNoctalia` to wire up spawn/keybind commands), since flake-parts merges all `perSystem` blocks per-system before evaluation.
