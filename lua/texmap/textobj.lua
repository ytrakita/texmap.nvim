local utils = require 'texmap.utils'

local vim = vim
local api = vim.api
local ts = vim.treesitter

local M = {}

local function select_range(r1, r2, r3, r4, mode)
  -- r1, ..., r4 are returned value of TSNode:range()
  mode = mode or 'v'
  api.nvim_win_set_cursor(0, { r1 + 1, r2 })
  local key = api.nvim_get_mode()['mode'] == 'v' and 'o' or mode
  vim.cmd([[normal!]] .. key)
  api.nvim_win_set_cursor(0, { r3 + 1, r4 - 1 })
end

function M.select_target(tgt_type, is_inner)
  local node = ts.get_node()
  local tgt_node = utils.get_node_of_type(node, tgt_type)
  if not tgt_node then return end

  local r1, r2, r3, r4

  if is_inner then
    r1, r2, r3, r4 = utils.get_inner_range(tgt_node, tgt_type)
  else
    r1, r2, r3, r4 = tgt_node:range()
  end

  select_range(r1, r2, r3, r4)
end

function M.init(config)
  local tbl = {
    section = 'sections',
    env = 'envs',
    dollar = 'inline_mathzones',
    item = 'items',
    delim = 'delims',
  }
  for key, type in pairs(tbl) do
    local a_key = ('<Plug>(a_%s)'):format(key)
    local i_key = ('<Plug>(i_%s)'):format(key)
    vim.keymap.set({ 'x', 'o' }, a_key, function()
      M.select_target(type)
    end)
    vim.keymap.set({ 'x', 'o' }, i_key, function()
      M.select_target(type, true)
    end)
  end
end

return M
