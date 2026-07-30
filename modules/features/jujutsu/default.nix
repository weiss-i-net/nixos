{ self, inputs, ... }: {
  perSystem =
    {
      pkgs,
      lib,
      self',
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
        };
      };
    };
}
