local utils = require("neo-tree.utils")
local defaults = require("neo-tree.defaults")

-- If you add a new source, you need to add it to the sources table.
-- Each source should have a defaults module that contains the default values
-- for the source config, and a setup function that takes that config.
local sources = {
  "filesystem",
}

local M = { }

local ensure_config = function ()
  if not M.config then
    M.setup({})
  end
end

M.focus = function(source_name)
  ensure_config()
  source_name = source_name or M.config.default_source
  local source = require('neo-tree.sources.' .. source_name)
  source.focus()
end

M.setup = function(config)
  -- setup the default values for all sources
  local sd = {}
  for _, source_name in ipairs(sources) do
    local mod_root = "neo-tree.sources." .. source_name
    sd[source_name] = require(mod_root .. ".defaults")
    sd[source_name].components = require(mod_root .. ".components")
    sd[source_name].commands = require(mod_root .. ".commands")
  end
  local default_config = utils.table_merge(defaults, sd)

  -- apply the users config
  M.config = utils.table_merge(default_config, config or {})

  -- setup the sources with the combined config
  for _, source_name in ipairs(sources) do
    local source = require('neo-tree.sources.' .. source_name)
    source.setup(M.config[source_name])
  end
end

M.show = function(source_name)
  ensure_config()
  source_name = source_name or M.config.default_source
  local source = require('neo-tree.sources.' .. source_name)
  source.show()
end

return M