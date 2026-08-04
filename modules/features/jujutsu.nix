{
  inputs,
  moduleWithSystem,
  ...
}:
{
  flake.nixosModules.jujutsu = moduleWithSystem (
    { self', ... }: {
      environment.systemPackages = [ self'.packages.myJujutsu ];
    }
  );

  perSystem =
    {
      pkgs,
      ...
    }:
    {
      packages.myJujutsu = inputs.wrapper-modules.wrappers.jujutsu.wrap {
        inherit pkgs;
        settings = {
          user = {
            name = "Jannik Hiller";
            email = "jannik.hiller@live.de";
          };
          ui.default-command = "log";
        };
      };
    };
}
