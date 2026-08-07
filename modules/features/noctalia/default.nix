{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.noctalia = moduleWithSystem (
    { self', ... }:
    {
      home-manager.sharedModules = [
        inputs.noctalia.homeModules.default
        {
          programs.noctalia = {
            enable = true;
            package = self'.packages.myNoctalia;

            # Deliberately empty: with no settings the module writes no
            # xdg.configFile, which leaves ~/.config/noctalia/config.toml a
            # plain writable file that noctalia's own settings UI can persist
            # to. Moving a config in here trades that for build-time
            # validation and a read-only store symlink.
            settings = { };
          };
        }
      ];
    }
  );

  perSystem =
    { system, ... }:
    {
      # A plain re-export, not a wrapper-modules wrap -- the "my" prefix is only
      # kept so the package name matches every other feature module (and so the
      # checks in modules/checks.nix pick it up). Once nixpkgs ships noctalia 5,
      # this and the flake input can both go away in favour of pkgs.noctalia.
      packages.myNoctalia = inputs.noctalia.packages.${system}.default;
    };
}
