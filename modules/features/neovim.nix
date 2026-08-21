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
      environment.sessionVariables.EDITOR = "nvim";
      home-manager.sharedModules = [
        {
          xdg.configFile = {
            "nvim" = {
              source = inputs.astronvim-template;
              recursive = true;
            };
            "nvim/lua/plugins/systemlsps.lua" = {
              text = ''
                return {
                  "AstroNvim/astrolsp",
                  ---@type AstroLSPOpts
                  opts = {
                    servers = { "hls", "nixd" },
                    config = {},
                  },
                }
              '';
            };
          };
        }
      ];
    }
  );

  perSystem =
    { pkgs, ... }:
    {
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

          nixd

          ghc
          cabal-install
          stack
          haskell-language-server
          ormolu

          git
          curl
          unzip
        ];
      };
    };
}
