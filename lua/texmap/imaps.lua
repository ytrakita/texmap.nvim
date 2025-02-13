local utils = require 'texmap.utils'

local vim = vim
local api = vim.api
local ts = vim.treesitter

local M = {}

local function is_bw_dollars(node)
  if node:type() ~= 'ERROR' then return end

  local line = api.nvim_get_current_line()
  local col = api.nvim_win_get_cursor(0)[2]
  local left = line:sub(col, col)
  local right = line:sub(col + 1, col + 1)
  return left == '$' and right == '$'
end

local function is_mathzone(node)
  if not node then return false end

  while node do
    if utils.is_type_of(node, 'non_mathzones') then
      return false
    elseif utils.is_type_of(node, 'mathzones') or is_bw_dollars(node) then
      return true
    end
    node = node:parent()
  end

  return false
end

function M.wrap_triv(_, rhs)
  return rhs
end

function M.wrap_math(lhs, rhs)
  local node = ts.get_node()
  return is_mathzone(node) and rhs or lhs
end

-- imap = { lhs, rhs, expr, leader, wrapper, context }
function M.set(imap, select_mode)
  local wrap = imap.wrapper or 'wrap_math'
  local mode = select_mode and { 'i', 's' } or { 'i' }
  local lhs = imap.leader .. imap.lhs
  local rhs = function() return M[wrap](lhs, imap.rhs) end

  vim.keymap.set(mode, lhs, rhs, { expr = true, buffer = true })
end

function M.init(config)
  local imaps = config.imaps
  for _, imap in ipairs(imaps.enable) do
    imap.leader = imap.leader or imaps.leader
    M.set(imap, imaps.select_mode)
  end

  for _, imap in ipairs(imaps.disable) do
    if type(imap) == 'string' then
      imap = { lhs = imap }
    end
    local lhs = (imap.leader or imaps.leader) .. imap.lhs
    local mode = imaps.select_mode and { 'i', 's' } or { 'i' }
    vim.keymap.del(mode, lhs, { buffer = true })
  end
end

return M
