local defaults = require 'texmap.defaults'
local imaps = require 'texmap.imaps'
local motions = require 'texmap.motions'
local surrounds = require 'texmap.surrounds'
local textobj = require 'texmap.textobj'

local M = {}

M.config = {
  imaps = {
    leader = "'",
    enable = {},
    disable = {},
    select_mode = true,
  },
  use_default = true,
  highlights = defaults.highlights,
}

local function tbl_merge(tbl1, tbl2)
  local ret_tbl = vim.deepcopy(tbl1)

  for i, val in ipairs(tbl2) do
    ret_tbl[#tbl1 + i] = val
  end

  return ret_tbl
end

function M.init(config)
  imaps.init(config)
  motions.init(config)
  surrounds.init(config)
  textobj.init(config)
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  if M.config.use_default then
    M.config.imaps.enable = tbl_merge(defaults.imaps.enable, opts.imaps.enable)
  end

  M.init(M.config)
end

return M
