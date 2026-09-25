{ inputs, ... }:
{
  perSystem =
    {
      system,
      pkgs,
      self',
      ...
    }:
    let
      # claude-code is unfree; keep that scoped to this shell.
      pkgsUnfree = import inputs.nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      devShells.default = pkgs.mkShell {
        packages = [
          pkgs.gh
          pkgsUnfree.claude-code
          self'.packages.myJujutsu
          pkgs.sops
          pkgs.age
        ];
      };
    };
}
