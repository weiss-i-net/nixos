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

      # Set here, not in system/desktop.nix: nvim only exists where this module
      # is imported, and desktop does not import it.
      environment.sessionVariables.EDITOR = "nvim";

      home-manager.sharedModules = [
        {
          xdg.configFile = {
            # Linked file-by-file rather than as a single directory symlink, so
            # that repo-managed spec files can be dropped in alongside the
            # template's own without vendoring the whole tree.
            "nvim" = {
              source = inputs.astronvim-template;
              recursive = true;
            };

            # The template ships astrolsp.lua disabled, so AstroNvim enables no
            # server that mason did not install. hls has to come from nix --
            # mason's prebuilt binaries do not run on NixOS -- which means it is
            # invisible to AstroNvim unless it is named here.
            "nvim/lua/plugins/haskell.lua".text = ''
              ---@type LazySpec
              return {
                "AstroNvim/astrolsp",
                ---@type AstroLSPOpts
                opts = {
                  servers = { "hls" },
                },
              }
            '';
          };
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
      # profile, which keeps the compilers and downloaders that exist solely for
      # treesitter and mason out of the interactive shell.
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

          # Haskell toolchain for hls, which mason cannot install here (it ships
          # prebuilt binaries that do not run on NixOS). runtimePkgs land at the
          # *end* of PATH, so a project's own devShell toolchain shadows these --
          # they are only the fallback for files outside such a shell.
          ghc
          cabal-install
          stack
          haskell-language-server
          ormolu

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
