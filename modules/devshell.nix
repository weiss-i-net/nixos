{ inputs, ... }:
{
  perSystem =
    {
      system,
      pkgs,
      self',
      lib,
      ...
    }:
    let
      # claude-code is unfree; only allow it for this local pkgs instance rather
      # than flipping allowUnfree on for every perSystem package.
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
        shellHook = "exec ${lib.getExe pkgs.fish}";
      };
    };
}
