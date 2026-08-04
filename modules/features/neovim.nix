{
  inputs,
  moduleWithSystem,
  ...
}:
{

  flake.nixosModules.neovim = moduleWithSystem (
    { self', ... }:
    {
      environment.systemPackages = [ self'.packages.myNeovim ];
      home-manager.sharedModules = [
        {
          xdg.configFile."nvim".source = inputs.astronvim-template;
        }
      ];
    }
  );

  perSystem =
    { pkgs, ... }:
    {
      # An otherwise bare neovim -- no specs, no generated config -- wrapped only
      # to carry AstroNvim's runtime dependencies. The wrapper puts them on PATH
      # for nvim's own child processes instead of installing them into the user
      # profile, which keeps a toolchain that exists solely for treesitter and
      # mason out of the interactive shell.
      packages.myNeovim = inputs.wrapper-modules.wrappers.neovim.wrap {
        inherit pkgs;
        runtimePkgs = with pkgs; [
          ripgrep
          fd
          lazygit
          gcc
          tree-sitter
          cargo
          nodejs
          python3

          # lazy.nvim clones the plugin set itself on first launch, and
          # mason.nvim (LSP/formatter/linter installer) downloads its tools at
          # runtime rather than through nix.
          git
          curl
          unzip
        ];
      };
    };
}
