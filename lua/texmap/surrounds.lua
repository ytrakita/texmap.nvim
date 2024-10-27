local utils = require 'texmap.utils'

local vim = vim
local api = vim.api
local ts = vim.treesitter

local M = {}

M.type_tbl = {
  envs = {
    c = 'rename_env',
    d = 'delete_env',
  },
  inline_mathzones = {
    c = 'display_dollars',
    d = 'delete_dollars',
  },
  delims = {
    c = 'resize_delims',
    d = 'delete_delims',
  },
}

local function get_surround_ranges(tgt_node, tgt_type)
  local cnt = tgt_node:child_count()
  local ret_tbl = {}
  for _, idx in ipairs({ 0, cnt - 1 }) do
    local s_node = tgt_node:child(idx)
    if tgt_type == 'envs' then
      s_node = s_node:child(0):next_sibling():child(0):next_sibling()
    end
    local s_node_range = { s_node:range() }
    if tgt_type == 'delims' then
      if idx == 0 then
        s_node = s_node:next_sibling()
        local _, _, r3, r4 = s_node:range()
        s_node_range[3], s_node_range[4] = r3, r4
      else
        s_node = s_node:prev_sibling()
        local r1, r2, _, _ = s_node:range()
        s_node_range[1], s_node_range[2] = r1, r2
      end
    end
    table.insert(ret_tbl, s_node_range)
  end
  return unpack(ret_tbl)
end

local mark_ns = api.nvim_create_namespace('texmap_surrounds')

local function highlight_surrounds(b_range, e_range)
  local mark_id_tbl = {}
  for _, range in ipairs({ b_range, e_range }) do
    local id = api.nvim_buf_set_extmark(0, mark_ns, range[1], range[2], {
      end_row = range[3],
      end_col = range[4],
      hl_group = 'texmapsurrounds',
    })
    table.insert(mark_id_tbl, id)
  end
  return mark_id_tbl
end

local function replace_text(node, lines)
  local r1, r2, r3, r4 = node:range()
  api.nvim_buf_set_text(0, r1, r2, r3, r4, lines)
  vim.cmd(('normal!%sGV%sG='):format(r1 + 1, r1 + #lines))
end

local function dollarize_env(env_node)
  local r1, r2, r3, r4 = utils.get_inner_range(env_node, 'envs')
  if not (r1 and r2 and r3 and r4) then return end

  local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})
  lines[1] = '$' .. lines[1]
  lines[#lines] = lines[#lines] .. '$'
  replace_text(env_node, lines)
end

local function toggle_env_star(env_node, is_star)
  local r1, r2, r3, r4 = env_node:range()
  local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})

  if is_star then
    lines[1] = lines[1]:gsub('^(\\begin{%w+)%*}', '%1}')
    lines[#lines] = lines[#lines]:gsub('%*}$', '}')
  else
    lines[1] = lines[1]:gsub('^(\\begin{%w+)}', '%1*}')
    lines[#lines] = lines[#lines]:gsub('}$', '*}')
  end

  api.nvim_buf_set_text(0, r1, r2, r3, r4, lines)
end

local function rename_env(env_node, input)
  local r1, r2, r3, r4 = env_node:range()
  local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})

  lines[1] = lines[1]:gsub('^(\\begin{)%w+', '%1' .. input)
  lines[#lines] = lines[#lines]:gsub('%w+([^%w]+)$', input .. '%1')

  api.nvim_buf_set_text(0, r1, r2, r3, r4, lines)
end

local cs_fn_tbl = {}

function cs_fn_tbl.rename_env(b_range, _, srnd_node)
  vim.ui.input({ prompt = 'New environment: ' }, function(input)
    if not input or input == '' then return end
    if input == '$' then dollarize_env(srnd_node) return end

    local r3, r4 = b_range[3], b_range[4]
    local last_char = api.nvim_buf_get_text(0, r3, r4 - 1, r3, r4, {})[1]
    local is_star = last_char == '*'

    if input == '*' then toggle_env_star(srnd_node, is_star) return end

    rename_env(srnd_node, input)
  end)
end

function cs_fn_tbl.display_dollars(b_range, e_range, srnd_node)
  vim.ui.input({ prompt = 'New environment: ' }, function(input)
    if not input or input == '' then return end

    local r1, r2, r3, r4 = utils.get_inner_range(srnd_node, 'inline_mathzones')
    if not (r1 and r2 and r3 and r4) then return end
    local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})

    vim.cmd('normal!' .. r3 + 1 .. 'G$')
    local is_head = b_range[2] == 0
    local is_tail = e_range[4] == api.nvim_win_get_cursor(0)[2] + 1

    table.insert(lines, 1, ('\\begin{%s}'):format(input))
    table.insert(lines, ('\\end{%s}'):format(input))
    if not is_head then
      table.insert(lines, 1, '')
    end
    if not is_tail then
      table.insert(lines, '')
    end

    replace_text(srnd_node, lines)
  end)
end

function cs_fn_tbl.resize_delims(_, _, srnd_node)
  local items = { 'normal', 'big', 'Big', 'bigg', 'Bigg', 'auto' }
  local opts = { prompt = 'New size: ' }
  vim.ui.select(items, opts, function(item)
    local r1, r2, r3, r4 = srnd_node:range()
    local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})

    local size_cmd_l = '\\' .. item .. 'l'
    local size_cmd_r = '\\' .. item .. 'r'
    if item == 'normal' then
      size_cmd_l, size_cmd_r = '', ''
    elseif item == 'auto' then
      size_cmd_l, size_cmd_r = '\\left', '\\right'
    end
    lines[1] = lines[1]:gsub('^\\%w+', size_cmd_l)
    lines[#lines] = lines[#lines]:gsub('\\%w+([^%w]+)$', size_cmd_r .. '%1')
    api.nvim_buf_set_text(0, r1, r2, r3, r4, lines)
  end)
end

local function change_surrounds(b_range, e_range, srnd_node, type)
  local cs_fn = cs_fn_tbl[M.type_tbl[type].c]
  cs_fn(b_range, e_range, srnd_node)
end

function M.change_surrounds(type)
  local node = ts.get_node()
  local srnd_node = utils.get_node_of_type(node, type)
  if not srnd_node then return end

  local b_range, e_range = get_surround_ranges(srnd_node, type)
  local mark_id_tbl = highlight_surrounds(b_range, e_range)

  vim.schedule(function()
    change_surrounds(b_range, e_range, srnd_node, type)

    for _, id in ipairs(mark_id_tbl) do
      api.nvim_buf_del_extmark(0, mark_ns, id)
    end
  end)
end

function M.delete_surrounds(type)
  local node = ts.get_node()
  local tgt_node = utils.get_node_of_type(node, type)
  if not tgt_node then return end

  local r1, r2, r3, r4 = utils.get_inner_range(tgt_node, type)
  if not (r1 and r2 and r3 and r4) then return end
  local lines = api.nvim_buf_get_text(0, r1, r2, r3, r4, {})
  replace_text(tgt_node, lines)
end

function M.init(config)
  api.nvim_set_hl(0, 'texmapSurrounds', config.highlights.texmapSurrounds)

  for tgt_type, key in pairs(M.type_tbl) do
    local c_lhs = ('<Plug>(%s)'):format(key.c)
    local d_lhs = ('<Plug>(%s)'):format(key.d)
    vim.keymap.set('n', c_lhs, function()
      M.change_surrounds(tgt_type)
    end)
    vim.keymap.set('n', d_lhs, function()
      M.delete_surrounds(tgt_type)
    end)
  end
end

return M
