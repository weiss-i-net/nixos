# CLAUDE.md

Guidance for Claude Code (claude.ai/code) working in this repo.

## Guiding principle: minimal, not general

This is one person's NixOS config for a couple of personal machines. Readability
beats flexibility, and **premature generalization is the main thing to avoid**:

- **Don't build an options interface for a single consumer.** `lib.mkOption`
  schemas, `mkEnableOption`, `submodule` types and `mapAttrs'` unit generation
  are for modules with several independent users. With one caller, write the
  config where it's used. A module used by exactly one host belongs in that
  host's config, not in a generic one with a `cfg` indirection in front of it.
- **Generalize on the third use.** Two similar blocks in two files are fine, and
  usually clearer than a parameterized module. An option never set to anything
  but its default is dead weight: delete the option, keep the value.
- **No config for hosts or hardware that don't exist.** No extra architecture
  until a host needs it, no keybinds or flags that are "harmless to have ready".
- **Prefer the literal** over a `let` binding used once or twice that only hides
  which package or value it is.
- **Few comments, and only for *why*.** A comment restating the code below it
  should be deleted. Reserve them for what the code can't say: hardware
  workarounds, a flag whose absence breaks something non-obviously, a
  deliberate-looking oddity that would otherwise get "fixed". One line where
  one line does.
- **Delete rather than keep:** unused flake inputs, `nixosModules` nothing
  imports, packages nothing installs.

When existing code violates this, say so rather than extending it in the same
style.

## Version control: jj, not git

Colocated `jj`/`git` repo (both `.jj/` and `.git/` exist). Use Jujutsu — the
`jj-vcs` skill auto-activates and covers the workflow. `.git` exists only for jj
colocation and flake `git+file` resolution: don't run `git commit`/`git add`.
Commit messages here are `scope: lowercase summary`.

## Commands

- `nix flake check` — the correctness gate. `modules/checks.nix` derives the
  check set from `nixosConfigurations` and `perSystem.packages`, so every host
  closure and every package is built, plus a treefmt check that fails on
  anything `nix fmt` would change. New hosts and packages are covered
  automatically.
- `nix fmt` — format *and lint-fix* (nixfmt + deadnix + statix). The linters
  edit in place, so review the diff.
- `nixos-rebuild build --flake .#<host>` — build one host without switching.
- `sudo nixos-rebuild switch --flake .#<host>` — only when explicitly asked.
- `nix build .#<package>` — build a single package.
- `nix flake show .` — list outputs, sanity-check evaluation.
- `sops modules/system/secrets/secrets.yaml` — edit the encrypted secrets.
  `nix develop` provides `sops` and `age`.

## Architecture

### Dendritic pattern via import-tree + flake-parts

`flake.nix` declares inputs and calls `flake-parts.lib.mkFlake` with
`inputs.import-tree ./modules`. **Every `.nix` file under `modules/` is loaded
automatically** — there is no import list to maintain, and a file's name and
location affect organization only, never whether it is active.

Each file is a flake-parts module contributing to the flake's outputs, usually
`flake.nixosModules.<name>`, `flake.nixosConfigurations.<name>`, or a `perSystem`
output like `packages.<name>`. Host configs, feature modules and package
definitions are peers in one tree, so read a file's `flake`/`perSystem` keys to
see what it produces instead of inferring from its path.

`modules/parts.nix` holds the `systems` list that drives `perSystem` evaluation.

### Module categories

- `features/` — one user-facing app or binary per module.
- `attrs/` — bundles composed of other modules; no binaries of their own.
- `system/` — system config with no binaries of its own, not standalone-usable,
  and knowing about no specific host or user. Anything only one host wants lives
  in that host instead.
- `hosts/` — per-machine config; output names match the subfolder name.

A module that is one Nix file lives at `<category>/<name>.nix`; the
`<name>/default.nix` folder form is for modules carrying extra non-Nix files
(wallpapers, scripts, `secrets.yaml`). Either way **`flake.nixosModules.<x>` is
named exactly after the file or folder, unprefixed** — `system/core.nix` gives
`nixosModules.core`, not `systemCore`.

Dependencies between `system/*` modules are expressed as `imports` inside them
rather than left for each host to wire up, so a host imports only what it
directly depends on and gets the rest transitively.

`system/secrets/` holds the sops-nix wiring and the encrypted file, nothing more:
*which* secrets get decrypted is declared by whoever needs them — a user module
for that user's, a host config for that machine's.

Two placement rules worth stating, since both look like they belong in shared
config and don't:

- `system.stateVersion` records the release a machine was installed at, so every
  host sets its own.
- Hardware-specific services (battery, thermals, GPU vendor tuning) belong to
  the host that has the hardware. A bundle imported by several machines may only
  contain what holds for all of them.

### Hosts

`modules/hosts/<name>/` holds three files:

- `<name>Hardware.nix` → `nixosModules.<name>Hardware`, hardware-scan output.
- `<name>Configuration.nix` → `nixosModules.<name>Configuration`, importing that
  hardware module plus the bundles the host wants, and holding everything
  specific to the machine.
- `default.nix` → `nixosConfigurations.<name>`, importing only that
  configuration module.

Adding a host means adding one such directory; nothing else changes.

### Features and wrapper-modules

A `features/*` module wraps a program with the `wrapper-modules` input
(`inputs.wrapper-modules.wrappers.<program>.wrap { inherit pkgs; settings = …; }`)
and exposes it as `perSystem.packages.my<Program>`. The config is generated from
Nix and embedded in the wrapped package, so there is no `~/.config/<program>` to
edit by hand: **change behavior by editing the module's `settings` (or the raw
`configBefore`/`configAfter` text) and rebuilding**, never by patching generated
output.

**wrapper-modules is the default; home-manager is the fallback.** Use a
`home-manager.sharedModules` entry only when a wrapper genuinely can't do the job
— none exists, or it can't express the config the program actually reads.
Familiarity is not a reason. A feature that departs from the wrapper pattern says
why in a comment at the top of its own file, so check there before assuming it
was an accident.

**Each `features/*` module produces both halves:** the `perSystem.packages.my<X>`
*and* a `flake.nixosModules.<x>` that installs it. The package alone installs
nothing, and a `nixosModules.<x>` that no bundle imports is inert — a silent
no-op rather than an evaluation error, so check the owning bundle lists it. How a
module installs its package is that program's business: usually
`environment.systemPackages`, but route through a `programs.<x>` option when the
program needs more than a binary on PATH. The plain `environment.systemPackages`
lists in `attrs/*` are for nixpkgs packages not worth a feature module — not for
`my*` packages.

Packages can reference each other as `self'.packages.<name>` inside `perSystem`,
since flake-parts merges every `perSystem` block per system before evaluation.

### Non-obvious behavior worth knowing

- **AstroNvim config is extended, not replaced.** The template is linked to
  `~/.config/nvim` with `recursive = true`, which makes home-manager materialize
  it as directories of individual symlinks and allows adding files inside the
  tree. That is the extension point: contribute
  `xdg.configFile."nvim/lua/plugins/<name>.lua".text` from the same module.
  Upstream's own files stay read-only store symlinks, so changing *those* means
  vendoring the tree.
- **A language server on PATH is invisible to AstroNvim.** The template disables
  its own lsp and community specs, so any server installed through nix instead of
  mason must be named in astrolsp's `servers` list.
- **niri binds match a physical key's unshifted keysym** plus the modifiers
  literally held; it does not resolve to the shifted character. On the German
  layout that makes several punctuation binds counter-intuitive (`/` is
  `Shift+7`, `[`/`]` are AltGr on `8`/`9`). Check the base keysym before adding
  one.
- **Programs with a settings UI keep a second config layer** that nix can't see.
  Promoting such tuning into the module is deliberate: export the merged config,
  port the preference keys, and leave app-managed runtime state (absolute paths,
  per-monitor geometry, schema versions) behind.
