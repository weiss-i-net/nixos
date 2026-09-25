{
  inputs,
  moduleWithSystem,
  ...
}:
# The wrapper generates no config here -- it only puts AstroNvim's external
# binaries on nvim's PATH (appended, so a project's devshell still wins). The
# config is the upstream template linked below, extended by adding spec files
# into the recursively-linked tree.
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
            # Mirrored to other devices, so an edit is only useful once it hits disk.
            "nvim/lua/plugins/autosaveSyncthing.lua" = {
              text = ''
                return {
                  "AstroNvim/astrocore",
                  ---@type AstroCoreOpts
                  opts = {
                    autocmds = {
                      autosave_syncthing = {
                        {
                          event = { "InsertLeave", "TextChanged", "FocusLost" },
                          pattern = vim.fn.expand("~/syncthing") .. "/*",
                          desc = "Autosave files in the syncthing folder",
                          command = "silent! update",
                        },
                      },
                    },
                  },
                }
              '';
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
