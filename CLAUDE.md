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
- `features/` — one module per wrapped app/binary (e.g. `neovim`, `kitty`, `tmux`).
- `attrs/` — attributes composed from other modules; no new features/binaries defined here, just bundling.
- `system/` — basic system config with no binaries of its own; not meant to be used standalone (network, audio, etc.).
- `hosts/` — per-machine presets; output names match the subfolder names (`nixosConfigurations.desktop`, `.harry`).

This is what determines where a new module belongs: a wrapped program goes in `features/`, a reusable bundle of other modules goes in `attrs/`, binary-less system config goes in `system/`, and machine-specific config goes in `hosts/`.

Within `features/`, `attrs/`, and `system/`, a module that's just a single Nix file with no other support files lives directly as `<category>/<name>.nix` (e.g. `attrs/base.nix`, `system/core.nix`, `features/tmux.nix`) — the `<name>/default.nix` folder form is reserved for modules that carry extra non-Nix files alongside it (e.g. `features/neovim/` for its lua files, `features/noctalia/` for `noctalia.json`, `system/secrets/` for `secrets.yaml`). Either way, the module's `flake.nixosModules.<x>` output must be named exactly `<name>` (matching the file/folder, no prefix — e.g. `system/core.nix` → `nixosModules.core`, not `systemCore`). `hosts/<name>/` always keeps its three-file folder shape regardless, since it's never single-file.

### Hosts

Each host lives in `modules/hosts/<name>/` with three files:
- `<name>Hardware.nix` — machine-specific hardware config (normally hardware-scan output, hand-edited for this host), defining `flake.nixosModules.<name>Hardware`.
- `<name>Configuration.nix` — defines `flake.nixosModules.<name>Configuration`, importing that host's hardware module, `self.nixosModules.base`, the `system/*` modules it needs directly (`core`, `desktop`, `secrets`, `user`), and (for `desktop`) `self.nixosModules.gaming`, plus setting host-specific options (e.g. `networking.hostName`, kernel workarounds, host-only packages/secrets).
- `default.nix` — defines `flake.nixosConfigurations.<name>` via `inputs.nixpkgs.lib.nixosSystem`, importing only `self.nixosModules.<name>Configuration`.

`modules/attrs/base.nix` defines `flake.nixosModules.base`, imported by every host. It's a generic feature/package bundle (tmux, jujutsu, neovim, goproWebcam, nix-index-database, general packages) with no knowledge of any specific user — it does not import `system/*` and does not define a user account, wire up home-manager, or enable niri (that's `system/desktop`'s concern, since niri is a desktop-environment component, not a generic feature).

`modules/attrs/gaming.nix` defines `flake.nixosModules.gaming`, an opt-in bundle (Steam, gamemode, gamescope, the LACT fan-control daemon) currently only imported by `desktop`, not `harry`.

`modules/system/` splits what used to be a single `common.nix` into one file per concern, each contributing a `flake.nixosModules.<name>` fragment matching its file/folder name (same convention as `features/*` — no `system`-prefixed names). Cross-dependencies between these modules are expressed as internal `imports` rather than left for every host to wire up — e.g. `core` imports `nixSettings`, `desktop` imports `homeManager` and `niri`, `user` imports `homeManager` and `secrets` — so a host only needs to import the modules it directly depends on; the rest come along transitively. Concerns too small to warrant their own file (NetworkManager, pipewire+rtkit) live directly in `core.nix` instead:
- `core.nix` — boot loader, locale/timezone, fish, NetworkManager, pipewire+rtkit, zram, `system.stateVersion`; imports `nixSettings`.
- `nixSettings.nix` — the `nix.settings`/`nix.gc` block (experimental-features, auto-optimise-store, weekly gc). Not imported directly by hosts — pulled in transitively via `core`.
- `desktop.nix` — imports `niri` (enables `programs.niri`) and `homeManager`; greetd+niri session, xkb layout, fonts, bluetooth, printing, upower, cursor env vars, desktop-environment packages (nautilus, gvfs, dconf), and the GNOME dark-theme preference applied user-agnostically via `home-manager.sharedModules`.
- `secrets/` — sops-nix wiring (`sops.defaultSopsFile`/`age.keyFile`) plus the `secrets.yaml` it decrypts; declares the `jannik-password` (used for the user's `hashedPasswordFile`) and `jannik-ssh-private-key` secrets. Per-host secrets (e.g. `harry`'s WireGuard keys) are declared directly in that host's `<name>Configuration.nix` instead.
- `homeManager.nix` — imports `inputs.home-manager.nixosModules.home-manager` and sets its global toggles (`useGlobalPkgs`, `useUserPackages`, `backupFileExtension`). Not imported directly by hosts — pulled in transitively via `desktop` and `user`.
- `user.nix` — imports `homeManager` and `secrets`; the concrete `jannik` NixOS account (uid, shell, sops-managed `hashedPasswordFile`, groups) plus its home-manager profile bootstrap (`home.stateVersion`, `programs.home-manager.enable`).

Host-specific quirks (e.g. the `dw9719` kernel module workaround on `harry` for IPU3 camera bring-up, or `thermald` for fan control) stay in that host's `<name>Configuration.nix` with a comment explaining the underlying hardware issue — keep that pattern (explain *why*, not what) for any new hardware workaround.

Adding a host means adding a new `modules/hosts/<name>/` directory following this same three-file shape; nothing elsewhere needs to change since `import-tree` picks it up automatically.

### wrapper-modules for user-facing programs

`modules/features/<program>.nix` (single-file programs: `jujutsu`, `kitty`, `niri`, `tmux`) or `modules/features/<program>/default.nix` (programs with extra support files: `neovim/`, `noctalia/`, `goproWebcam/`) mostly wrap TUI/GUI programs using the `wrapper-modules` flake input (`inputs.wrapper-modules.wrappers.<program>.wrap { inherit pkgs; settings = { ... }; }`), exposed as `perSystem.packages.my<Program>` (e.g. `myNeovim`, `myKitty`, `myTmux`, `myJujutsu`, `myNiri`, `myNoctalia`). This generates the program's config file(s) from Nix attrsets/strings instead of hand-written dotfiles — the wrapped package embeds its config, so there is no `~/.config/<program>` to edit by hand. The multi-file feature directories carry their extra non-Nix support files alongside `default.nix` (e.g. `neovim/astronvim-init.lua` and `neovim/bridge-plugin/` for its Lua plugin bridge, `noctalia/noctalia.json` read via `builtins.fromJSON`) — the same rule applies to those: edit and rebuild, don't hand-patch generated output. **To change a program's behavior, edit its `settings` (or `configBefore`/`configAfter` for raw config text, as in `tmux.nix`) in the corresponding `modules/features/<program>.nix` (or `.../default.nix`) file and rebuild** — do not edit generated config files directly (see the intentional "config is managed by Nix" tmux binding in `modules/features/tmux.nix`).

`niri.nix` is the one feature module that also produces a `flake.nixosModules.niri` (a real NixOS module enabling `programs.niri` system-wide with the wrapped package), in addition to its `perSystem.packages.myNiri`. That NixOS module is imported by `modules/system/desktop.nix` (niri being a desktop-environment concern, not a generic feature, so it's owned there rather than by `attrs/base.nix`). Other feature modules only produce `perSystem` packages, which get pulled into `environment.systemPackages` by whichever module needs them (mostly `attrs/base.nix`, plus `attrs/gaming.nix` for its own package).

Wrapped packages can reference each other across modules via `self'.packages.<name>` inside `perSystem` (e.g. `niri.nix` uses `self'.packages.myKitty` and `self'.packages.myNoctalia` to wire up spawn/keybind commands), since flake-parts merges all `perSystem` blocks per-system before evaluation.
