{ self, lib, ... }:
{
  perSystem =
    { self', ... }:
    {
      # `nix flake check` only evaluates nixosConfigurations and packages;
      # listing them as checks is what makes it actually build them, which is
      # the closest thing this repo has to a test suite.
      checks =
        lib.mapAttrs' (
          name: cfg: lib.nameValuePair "host-${name}" cfg.config.system.build.toplevel
        ) self.nixosConfigurations
        // self'.packages;
    };
}
