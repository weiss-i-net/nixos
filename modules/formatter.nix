{ inputs, ... }:
{
  imports = [ inputs.treefmt-nix.flakeModule ];

  # treefmt-nix sets `formatter` itself and, via flakeCheck, adds a
  # `checks.treefmt` that fails on anything `nix fmt` would have changed --
  # so the deadnix/statix lints that used to be fixed by hand are now both
  # auto-applied and gated.
  perSystem.treefmt = {
    projectRootFile = "flake.nix";
    programs = {
      nixfmt.enable = true;
      deadnix.enable = true;
      statix.enable = true;
    };

    # Run the linters before the formatter (lower priority goes first): their
    # rewrites are not themselves nixfmt-shaped, so with the default ordering
    # a file statix touched could come out unformatted and fail checks.treefmt
    # on the next run.
    settings.formatter = {
      deadnix.priority = 1;
      statix.priority = 2;
      nixfmt.priority = 3;
    };
  };
}
