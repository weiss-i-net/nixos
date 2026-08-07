{
  moduleWithSystem,
  self,
  ...
}:
{
  flake.nixosModules.devel = moduleWithSystem (
    _:
    { pkgs, ... }:
    {
      imports = with self.nixosModules; [
        jujutsu
        neovim
        tmux
      ];

      environment.systemPackages = with pkgs; [
        git
        claude-code
        devenv
        gh
      ];
    }
  );
}
