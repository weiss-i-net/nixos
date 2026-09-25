{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  # treefmt-nix also adds a checks.treefmt that fails on anything `nix fmt`
  # would have changed, so the lints are gated as well as auto-applied.
  perSystem.treefmt = {
    projectRootFile = "flake.nix";
    programs = {
      nixfmt.enable = true;
      deadnix.enable = true;
      statix.enable = true;
    };

    # Linters first (lower priority runs first): their rewrites aren't
    # nixfmt-shaped, so nixfmt has to clean up after them.
    settings.formatter = {
      deadnix.priority = 1;
      statix.priority = 2;
      nixfmt.priority = 3;
    };
  };
}
