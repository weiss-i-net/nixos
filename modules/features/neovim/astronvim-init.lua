-- Entry point: lists the actual AstroNvim spec files to resolve and hands
-- them to the generic resolver in astronvim-bridge.lua. See that file for why
-- this exists instead of just using AstroNvim's own init.lua/lazy_setup.lua.
-- A handful of plugins (e.g. astroui's lazygit config export) write into
-- stdpath("cache")/stdpath("state") without creating it first, which only
-- exists already on a non-fresh $HOME.
for _, kind in ipairs { "cache", "state", "data" } do
  vim.fn.mkdir(vim.fn.stdpath(kind), "p")
end

local bridge = require "astronvim-bridge"

-- lua/astronvim/plugins/*.lua from the real AstroNvim/AstroNvim core repo
-- (astronvim-core flake input): AstroNvim's default plugin set.
local core = {
  "astronvim.plugins._astrocore",
  "astronvim.plugins._astrocore_options",
  "astronvim.plugins._astrocore_autocmds",
  "astronvim.plugins._astrocore_mappings",
  "astronvim.plugins._astrolsp",
  "astronvim.plugins._astrolsp_autocmds",
  "astronvim.plugins._astrolsp_mappings",
  "astronvim.plugins._astroui",
  "astronvim.plugins._astroui_status",
  "astronvim.plugins._astrotheme",
  "astronvim.plugins.aerial",
  "astronvim.plugins.autopairs",
  "astronvim.plugins.better-escape",
  "astronvim.plugins.blink",
  "astronvim.plugins.dap",
  "astronvim.plugins.gitsigns",
  "astronvim.plugins.guess-indent",
  "astronvim.plugins.heirline",
  "astronvim.plugins.highlight-colors",
  "astronvim.plugins.lazydev",
  "astronvim.plugins.lspconfig",
  "astronvim.plugins.luasnip",
  "astronvim.plugins.mason-lspconfig",
  "astronvim.plugins.mason",
  "astronvim.plugins.mason-tool-installer",
  "astronvim.plugins.mini-icons",
  "astronvim.plugins.neo-tree",
  "astronvim.plugins.none-ls",
  "astronvim.plugins.resession",
  "astronvim.plugins.smart-splits",
  "astronvim.plugins.snacks",
  "astronvim.plugins.todo-comments",
  "astronvim.plugins.toggleterm",
  "astronvim.plugins.treesitter",
  "astronvim.plugins.treesitter-textobjects",
  "astronvim.plugins.ts-autotag",
  "astronvim.plugins.which-key",
  "astronvim.plugins.window-picker",
}

-- lua/plugins/*.lua + lua/community.lua from astronvim-template (the
-- user-editable overrides). All `if true then return {} end`-guarded (inert)
-- until customized -- edit them the same way the AstroNvim docs describe,
-- `nix build`/relaunch nvim to pick up changes.
local template = {
  "plugins.astrocore",
  "plugins.astrolsp",
  "plugins.astroui",
  "plugins.mason",
  "plugins.none-ls",
  "plugins.treesitter",
  "plugins.user",
  "community",
}

bridge.load { core, template }

-- lua/polish.lua: runs last, after every plugin above is set up. Its body
-- executes as a side effect of `require`, so nothing to do with the result.
local ok, err = pcall(require, "polish")
if not ok then vim.notify("astronvim-bridge: polish.lua failed: " .. err, vim.log.levels.ERROR) end
