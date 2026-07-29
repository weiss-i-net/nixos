-- Runs AstroNvim's own plugin-spec files (from the real AstroNvim/AstroNvim
-- core repo and the astronvim-template repo, both put on the runtimepath as
-- ordinary nix-wrapper-modules specs) WITHOUT lazy.nvim as the plugin manager.
--
-- AstroNvim v6 splits its actual behavior into standalone plugins (astrocore,
-- astrolsp, astroui, astrotheme) that expose a normal `require(x).setup(opts)`
-- API. The files below are just *lazy.nvim spec tables* describing which
-- opts to feed into those `.setup()` calls (and, for a handful of plugins,
-- a custom `config` function instead of a plain `opts` table). Since nix
-- already installs every plugin from nixpkgs (no lazy.nvim install/update
-- machinery needed), all that's missing is resolving those spec tables and
-- calling `.setup()` ourselves -- which is what this file does, generically,
-- so upstream spec files can be consumed unmodified and template edits under
-- `lua/plugins/*.lua` keep working without touching this bridge.

-- `require "astronvim"` only shows up for two harmless things in the spec
-- files: `astronvim.init()` (sets mapleader/notifies about pinned-plugin
-- updates -- both meaningless without lazy.nvim) and `:AstroVersion`'s
-- `astronvim.version()`. Stub it so those call sites don't need the full
-- (unpackaged) AstroNvim core module.
package.loaded.astronvim = {
  init = function() end,
  version = function() return "nix-managed" end,
  config = {},
}
vim.g.mapleader = " "
vim.g.maplocalleader = ","

local islist = vim.islist or vim.tbl_islist
local function is_list(t) return islist(t) end

-- dotted-path get/set, used for the small `opts_extend` (list-append instead
-- of list-replace) support that a few specs rely on.
local function get_path(t, path)
  for key in path:gmatch "[^.]+" do
    if type(t) ~= "table" then return nil end
    t = t[key]
  end
  return t
end
local function set_path(t, path, value)
  local keys = {}
  for key in path:gmatch "[^.]+" do table.insert(keys, key) end
  for i = 1, #keys - 1 do
    local key = keys[i]
    if type(t[key]) ~= "table" then t[key] = {} end
    t = t[key]
  end
  t[keys[#keys]] = value
end

-- Recursively flatten a LazySpec-shaped value (a single spec table, a list of
-- specs, or a bare plugin-name string) into a flat list of atomic specs,
-- following `.dependencies` and `.specs` and honoring static `cond`/`enabled`.
local function flatten(spec, out)
  out = out or {}
  if spec == nil then return out end
  if type(spec) == "string" then spec = { spec } end
  if is_list(spec) and (spec[1] == nil or type(spec[1]) ~= "string") then
    for _, s in ipairs(spec) do flatten(s, out) end
    return out
  end
  if spec.cond == false then return out end
  if type(spec.cond) == "function" and not spec.cond() then return out end
  if spec.enabled == false then return out end
  table.insert(out, spec)
  if spec.dependencies then flatten(spec.dependencies, out) end
  if spec.specs then flatten(spec.specs, out) end
  return out
end

local function plugin_name(spec)
  local repo = spec[1]
  if not repo then return spec.name end
  local base = repo:match "([^/]+)$" or repo
  return (base:gsub("%.nvim$", ""))
end

-- A handful of plugins' real lua module name doesn't match their (nvim-
-- suffix-stripped) repo basename, and upstream doesn't set `main` for them
-- because lazy.nvim's installer resolves this via fuzzy directory search.
local main_overrides = {
  ["better-escape"] = "better_escape",
}

local M = {}

function M.load(root_specs)
  local groups, order = {}, {}
  -- A couple of our plugins pull in the real (unused) `lazy.nvim` package
  -- transitively as a nixpkgs dependency. astrocore/astrolsp code paths that
  -- do `pcall(require, "lazy.core.config")` to ask lazy.nvim things (is this
  -- plugin installed, defer this callback until plugin X loads, ...) would
  -- otherwise find it, assume it's a fully working lazy.nvim, and crash on
  -- its never-populated `.spec`/`.plugins` fields. Force that require to
  -- fail instead, so those code paths take their "lazy not available"
  -- fallback -- `is_available`/`get_plugin`/`plugin_opts` are separately
  -- monkeypatched below to answer from our own registry rather than falling
  -- back to "unavailable".
  for _, mod_name in ipairs { "lazy.core.config", "lazy.core.plugin" } do
    package.preload[mod_name] = function() error(mod_name .. ": not available (nix-managed config, no lazy.nvim)") end
  end

  -- Registry of every plugin we actually installed, keyed by raw repo
  -- basename (the exact string `is_available`/`get_plugin` calls use).
  local installed = {}
  local function add(spec)
    local repo = spec[1]
    if repo then installed[repo:match "([^/]+)$" or repo] = true end
    local name = plugin_name(spec)
    if not name then return end
    if not groups[name] then
      groups[name] = {}
      table.insert(order, name)
    end
    table.insert(groups[name], spec)
  end
  for _, files in ipairs(root_specs) do
    for _, mod in ipairs(files) do
      local ok, spec = pcall(require, mod)
      if not ok then
        vim.notify(("astronvim-bridge: failed to load %s: %s"):format(mod, spec), vim.log.levels.WARN)
      elseif spec and next(spec) ~= nil then
        for _, s in ipairs(flatten(spec)) do add(s) end
      end
    end
  end
  local resolve_cache = {}
  local function resolve(name)
    if resolve_cache[name] then return unpack(resolve_cache[name]) end
    local specs = groups[name] or {}
    local opts, config_fn, main = {}, nil, nil
    for _, spec in ipairs(specs) do
      if spec.main then main = spec.main end
      if type(spec.config) == "function" then config_fn = spec.config end
      if type(spec.opts) == "function" then
        opts = spec.opts(spec, opts) or opts
      elseif type(spec.opts) == "table" then
        local new_opts = spec.opts
        if spec.opts_extend then
          new_opts = vim.deepcopy(new_opts)
          for _, path in ipairs(spec.opts_extend) do
            local existing, incoming = get_path(opts, path), get_path(new_opts, path)
            if type(existing) == "table" and type(incoming) == "table" then
              set_path(new_opts, path, vim.list_extend(vim.deepcopy(existing), incoming))
            end
          end
        end
        opts = vim.tbl_deep_extend("force", opts, new_opts)
      end
    end
    resolve_cache[name] = { opts, config_fn, main }
    return opts, config_fn, main
  end

  -- astrocore/astrolsp expose `is_available`/`get_plugin`/`plugin_opts`,
  -- which some plugins' opts functions use to ask lazy.nvim whether some
  -- *other* plugin is installed and, if so, what opts were resolved for it
  -- (e.g. blink.cmp's opts function reading snacks.nvim's picker opts).
  -- Point those at our own registry/resolver instead of lazy.nvim's.
  for _, mod_name in ipairs { "astrocore", "astrolsp" } do
    local ok, mod = pcall(require, mod_name)
    if ok then
      mod.is_available = function(raw_name) return installed[raw_name] == true end
      mod.get_plugin = function(raw_name) return installed[raw_name] and { raw_name } or nil end
      mod.plugin_opts = function(raw_name)
        local opts = resolve(plugin_name { raw_name })
        return opts or {}
      end
    end
  end

  local function setup(name)
    local ok, opts, config_fn, main = pcall(resolve, name)
    if not ok then
      vim.notify(("astronvim-bridge: failed to resolve opts for %s: %s"):format(name, opts), vim.log.levels.ERROR)
      return
    end
    local done, err = xpcall(function()
      if config_fn then
        config_fn({ name }, opts)
      elseif groups[name] and (next(opts) ~= nil or main) then
        local target = main or main_overrides[name] or name
        local mod = require(target)
        if mod.setup then mod.setup(opts) end
      end
    end, debug.traceback)
    if not done then vim.notify(("astronvim-bridge: failed to set up %s: %s"):format(name, err), vim.log.levels.ERROR) end
  end

  -- astroui/astrotheme/astrocore/astrolsp are depended on (directly or via
  -- `require("astrocore").config` etc.) by nearly everything else, so they
  -- must be set up first, in this order.
  local first = { "astroui", "astrotheme", "astrocore", "astrolsp" }
  for _, name in ipairs(first) do
    if groups[name] then setup(name) end
  end
  local done_first = { astroui = true, astrotheme = true, astrocore = true, astrolsp = true }
  for _, name in ipairs(order) do
    if not done_first[name] then setup(name) end
  end
end

return M
