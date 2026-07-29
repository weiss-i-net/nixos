{ self, inputs, ... }:
{

  perSystem =
    { pkgs, ... }:
    let
      # Every plugin AstroNvim v6's core (astronvim-core input) and the
      # template default to. Installed as plain nix-managed packDir entries
      # (no lazy.nvim, no runtime git clones) -- see
      # ./neovim/bridge-plugin/lua/astronvim-bridge.lua for how their
      # `opts`/`config` get wired up without lazy.nvim as the plugin manager.
      astronvimPluginNames = [
        "aerial-nvim"
        "astrocore"
        "astrolsp"
        "astrotheme"
        "astroui"
        "better-escape-nvim"
        "blink-cmp"
        "blink-compat"
        "cmp-dap"
        "friendly-snippets"
        "gitsigns-nvim"
        "guess-indent-nvim"
        "heirline-nvim"
        "lazydev-nvim"
        "luasnip"
        "mason-lspconfig-nvim"
        "mason-nvim"
        "mason-nvim-dap-nvim"
        "mason-null-ls-nvim"
        "mason-tool-installer-nvim"
        "mini-icons"
        "neo-tree-nvim"
        "none-ls-nvim"
        "nui-nvim"
        "nvim-autopairs"
        "nvim-dap"
        "nvim-dap-ui"
        "nvim-highlight-colors"
        "nvim-lspconfig"
        "nvim-nio"
        "nvim-treesitter"
        "nvim-treesitter-textobjects"
        "nvim-ts-autotag"
        "nvim-window-picker"
        "plenary-nvim"
        "resession-nvim"
        "smart-splits-nvim"
        "snacks-nvim"
        "todo-comments-nvim"
        "toggleterm-nvim"
        "which-key-nvim"
      ];

      astronvimSpecs = builtins.listToAttrs (
        map (name: {
          inherit name;
          value.data = pkgs.vimPlugins.${name};
        }) astronvimPluginNames
      );
    in
    {
      packages.myNeovim = inputs.wrapper-modules.wrappers.neovim.wrap {
        inherit pkgs;
        specs = astronvimSpecs // {
          # AstroNvim/AstroNvim itself: only used for its lua/astronvim/plugins/*.lua
          # spec files and lua/astronvim/plugins/configs/*.lua, consumed by the bridge.
          # (`// { name = ...; }`: flake inputs have no .name/.pname, which this
          # wrapper module's own derivation-name inference assumes exists.)
          astronvim-core.data = inputs.astronvim-core // {
            name = "astronvim-core";
          };
          # The user-editable template (lua/plugins/*.lua, community.lua, polish.lua).
          astronvim-template.data = inputs.astronvim-template // {
            name = "astronvim-template";
          };
          # Our own resolver, exposed as `require("astronvim-bridge")`. Wrapped
          # in a derivation (rather than passed as a bare path) for the same
          # reason: it needs a `.name` the wrapper module can introspect.
          astronvim-bridge.data = pkgs.runCommandLocal "astronvim-bridge" { } ''
            cp -r ${./neovim/bridge-plugin} $out
          '';
          # Runs the resolver over the core + template spec files above.
          astronvim-init = {
            data = null;
            config = builtins.readFile ./neovim/astronvim-init.lua;
          };
        };
        runtimePkgs = with pkgs; [
          stdenv
          ripgrep
          fd
          lazygit
          nodejs
          python3
          gcc
          tree-sitter
          cargo
          # mason.nvim (LSP/formatter/linter installer) still downloads its
          # tools itself at runtime rather than through nix.
          unzip
          curl
          git
        ];
      };

    };
}
