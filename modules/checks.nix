{ self, lib, ... }:
{
  perSystem =
    { system, self', ... }:
    {
      # `nix flake check` only evaluates nixosConfigurations and packages;
      # listing them as checks is what makes it actually build them, which is
      # the closest thing this repo has to a test suite.
      checks =
        lib.mapAttrs' (name: cfg: lib.nameValuePair "host-${name}" cfg.config.system.build.toplevel) (
          # Keyed by the platform each host builds for, so a future aarch64
          # host isn't dragged into the x86_64 check set (and vice versa).
          lib.filterAttrs (_: cfg: cfg.config.nixpkgs.hostPlatform.system == system) self.nixosConfigurations
        )
        // self'.packages;
    };
}
