local utils = require 'texmap.utils'
local ts_utils = require 'nvim-treesitter.ts_utils'

local vim = vim
local api = vim.api
local ts = vim.treesitter

local M = {}

-- TODO
-- go to matching delimiters   %

local query_string = [[
[
(part)
(chapter)
(section)
(subsection)
(subsubsection)
(paragraph)
(subparagraph)
] @module.latex
]]

local nav_fn_tbl = {}

function nav_fn_tbl.sections(node, is_prev)
  local root = node:tree():root()
  local query = ts.query.parse('latex', query_string)
  local lnum = api.nvim_win_get_cursor(0)[1] - (is_prev and 1 or 0)
  local prev_sec_node = node

  for _, sec_node, _ in query:iter_captures(root, 0, 0, -1) do
    if sec_node:range() >= lnum then
      local tgt_node = is_prev and prev_sec_node or sec_node
      return ts_utils.goto_node(tgt_node)
    end
    prev_sec_node = sec_node
  end

  local tgt_node = is_prev and prev_sec_node or node
  ts_utils.goto_node(tgt_node)
end

function nav_fn_tbl.items(node, is_prev)
  local src_node = utils.get_node_of_type(node, 'items')
  if not src_node then return end

  local tgt_node = src_node
  if is_prev then
    tgt_node = src_node:prev_sibling()
  else
    tgt_node = src_node:next_sibling()
  end
  if utils.is_type_of(tgt_node, 'items') then
    ts_utils.goto_node(tgt_node)
  end
end

function M.navigate(tgt_type, is_prev)
  local node = ts.get_node()
  nav_fn_tbl[tgt_type](node, is_prev)
end

function M.init(config)
  local tbl = {
    section = 'sections',
    item = 'items',
  }
  for key, type in pairs(tbl) do
    local next_key = ('<Plug>(next_%s)'):format(key)
    local prev_key = ('<Plug>(prev_%s)'):format(key)
    vim.keymap.set({ 'n', 'x', 'o' }, next_key, function()
      M.navigate(type)
    end)
    vim.keymap.set({ 'n', 'x', 'o' }, prev_key, function()
      M.navigate(type, true)
    end)
  end
end

return M
