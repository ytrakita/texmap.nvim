local vim = vim

local M = {}

M.type_tbls = {
  sections = {
    'part',
    'chapter',
    'section',
    'subsection',
    'subsubsection',
    'paragraph',
    'subparagraph',
  },
  envs = {
    'generic_environment',
    'math_environment',
  },
  non_inner_nodes = {
    'label_definition',
    'line_comment',
    'label',
    'brack_group_text'
  },
  mathzones = {
    'inline_formula',
    'displayed_equation',
    'math_environment',
    'subscript',
    'superscript',
  },
  non_mathzones = {
    'text_mode',
    'label_definition',
  },
  inline_mathzones = {
    'inline_formula',
  },
  delims = {
    'math_delimiter',
  },
  items = {
    'enum_item',
  },
}

M.inner_idx_tbl = {
  sections = { 2, 1 },
  envs = { 1, 2 },
  inline_mathzones = { 1, 2 },
  delims = { 2, 3 },
  items = { 1, 1 },
}

function M.is_type_of(node, type)
  return vim.tbl_contains(M.type_tbls[type], node:type())
end

function M.get_node_of_type(node, type)
  if not (node and M.type_tbls[type]) then return end
  while node and not M.is_type_of(node, type) do
    node = node:parent()
  end
  return node
end

function M.get_inner_range(node, type)
  local i_idx_tbl = M.inner_idx_tbl[type]
  if not i_idx_tbl then return end

  local start_idx = i_idx_tbl[1]
  local end_idx = node:child_count() - i_idx_tbl[2]

  local start_node = node:child(start_idx)
  while start_node and M.is_type_of(start_node, 'non_inner_nodes') do
    start_node = start_node:next_sibling()
  end
  local end_node = node:child(end_idx)

  local r1, r2, _, _ = start_node:range()
  local _, _, r3, r4 = end_node:range()

  return r1, r2, r3, r4
end

return M
