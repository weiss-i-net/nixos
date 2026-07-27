# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Version control: jj, not git

This repo is a colocated `jj`/`git` repo. Use Jujutsu (`jj`) commands, not `git`:

- `jj status`, `jj log` — inspect state / history
- `jj describe -m "message"` — set the description of the current change
- `jj new` — start a new change on top of the current one
- There is no separate staging area or index and no need to "commit" in the git sense — every edit to the working copy is automatically recorded as the current (`@`) change. Use `jj describe` to give it a message, and `jj new` to start the next one.
- The `.git` directory exists only for jj colocation and flake `git+file` resolution; don't run `git commit`/`git add` directly, operate through `jj`.

## Commands

- `nix flake show .` — list all outputs (hosts, packages, formatter) and sanity-check that the flake evaluates.
- `nixos-rebuild build --flake .#<host>` — build a host's system closure without switching (safest way to check a change compiles). Hosts: `desktop`, `harry`.
- `sudo nixos-rebuild switch --flake .#<host>` — apply on the local machine (only run this if explicitly asked to; it's a live-system change).
- `nix build .#<packageName>` — build a single wrapped package (e.g. `nix build .#myNeovim`) to check just that module.
- `nix fmt` — format the tree with `nixfmt-tree` (configured in `modules/formatter.nix`).
- There is no separate lint/test suite; `nix flake show` and `nixos-rebuild build` are the correctness checks.

## Architecture

### Dendritic pattern via import-tree + flake-parts

`flake.nix` is intentionally minimal: it declares inputs and calls `flake-parts.lib.mkFlake` with a single module list produced by `inputs.import-tree ./modules`. `import-tree` recursively imports every `.nix` file under `modules/` as a flake-parts module — there is no manual list of imports to maintain. **Any new `.nix` file dropped anywhere under `modules/` is automatically wired in**; naming/location controls organization only, not whether it's loaded.

Each module file is a self-contained flake-parts module (a function of `{ self, inputs, ... }` or similar) that contributes fragments to the flake's output attrsets — typically `flake.nixosModules.<name>`, `flake.nixosConfigurations.<name>`, or `perSystem` outputs like `packages.<name>`/`formatter`. Because every file can contribute to any output, host configs, feature modules, and package definitions are all peers in the same tree rather than being layered through a central `default.nix`. Read a file's `config`/`flake`/`perSystem` keys to know what it produces — don't assume based on its path.

`modules/parts.nix` sets `systems = [ "x86_64-linux" "aarch64-linux" ]`, which is what drives `perSystem` evaluation across both architectures.

### Hosts

Each host lives in `modules/hosts/<name>/` with three files:
- `hardware.nix` — machine-specific hardware config (normally hardware-scan output, hand-edited for this host).
- `configuration.nix` — defines `flake.nixosModules.<name>Configuration`, importing that host's hardware module plus `self.nixosModules.common`, and setting host-specific options (e.g. `networking.hostName`, kernel workarounds, host-only packages).
- `default.nix` — defines `flake.nixosConfigurations.<name>` via `inputs.nixpkgs.lib.nixosSystem`, importing only `self.nixosModules.<name>Configuration`.

`modules/hosts/common.nix` defines `flake.nixosModules.common`, shared across all hosts: boot loader, locale/timezone, greetd+niri session, xkb layout, audio (pipewire), the `jannik` user (including which wrapped packages get installed), nix settings (flakes, gc), and `system.stateVersion`. Host-specific quirks (e.g. the `dw9719` kernel module workaround on `harry` for IPU3 camera bring-up, or `thermald` for fan control) stay in that host's `configuration.nix` with a comment explaining the underlying hardware issue — keep that pattern (explain *why*, not what) for any new hardware workaround.

Adding a host means adding a new `modules/hosts/<name>/` directory following this same three-file shape; nothing elsewhere needs to change since `import-tree` picks it up automatically.

### wrapper-modules for user-facing programs

`modules/features/*.nix` mostly wrap TUI/GUI programs using the `wrapper-modules` flake input (`inputs.wrapper-modules.wrappers.<program>.wrap { inherit pkgs; settings = { ... }; }`), exposed as `perSystem.packages.my<Program>` (e.g. `myNeovim`, `myKitty`, `myTmux`, `myJujutsu`, `myNiri`, `myNoctalia`). This generates the program's config file(s) from Nix attrsets/strings instead of hand-written dotfiles — the wrapped package embeds its config, so there is no `~/.config/<program>` to edit by hand. **To change a program's behavior, edit its `settings` (or `configBefore`/`configAfter` for raw config text, as in `tmux.nix`) in the corresponding `modules/features/*.nix` file and rebuild** — do not edit generated config files directly (see the intentional "config is managed by Nix" tmux binding in `modules/features/tmux.nix`).

`niri.nix` is the one feature module that also produces a `flake.nixosModules.niri` (a real NixOS module enabling `programs.niri` system-wide with the wrapped package), in addition to its `perSystem.packages.myNiri`. That NixOS module is imported by `common.nix`. Other feature modules only produce `perSystem` packages, which get pulled into the user's package list in `common.nix`'s `users.users."jannik".packages`.

Wrapped packages can reference each other across modules via `self'.packages.<name>` inside `perSystem` (e.g. `niri.nix` uses `self'.packages.myKitty` and `self'.packages.myNoctalia` to wire up spawn/keybind commands), since flake-parts merges all `perSystem` blocks per-system before evaluation.
