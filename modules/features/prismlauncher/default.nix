{
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.prismlauncher = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = [ self'.packages.myPrismlauncher ];
    }
  );

  perSystem =
    { pkgs, ... }:
    {
      packages.myPrismlauncher = pkgs.prismlauncher.override {

        prismlauncher-unwrapped = pkgs.prismlauncher-unwrapped.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            ./prism_disable_account.patch
          ];
        });
      };
    };

}
