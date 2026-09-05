local M = {}
local highlights = require "godot-tools.highlights"

M.ns_id = vim.api.nvim_create_namespace "gdtools-hls"

M.icons = {
  node = "○",
  scene = "●",
}

---@param type string godot node type
---@return string icon
function M.icon_from_node(type)
  if not type or type == "PackedScene" then
    return M.icons.scene
  end
  return M.icons.node
end

---@class gdtools.Render.opts
local default_render_opts = {
  max_depth = 2,
  always_show_type = false,
}

---@class gdtools.HLSpan
---@field line integer
---@field col_beg integer
---@field col_end integer
---@field group string

---@param scene gdtools.Scene
---@param opts gdtools.Render.opts
---@return string[] lines, gdtools.HLSpan[] hl_spans
function M.scene_tree(scene, opts)
  opts = vim.tbl_deep_extend("force", default_render_opts, opts or {})

  local root = nil
  local children = {}
  for _, node in ipairs(scene.nodes) do
    if not node.parent then
      root = node
      continue
    end

    local parent
    if node.parent == "." then
      parent = ""
    else
      parent = "/" .. node.parent
    end
    children[parent] = children[parent] or {}
    children[parent][#children[parent] + 1] = node
  end

  local lines = {}
  local hl_spans = {}
  -- todo don't really like this, would rather not create a function each time
  local function walk(node_name, depth, prefix)
    local childs = children[node_name] or {}
    for i, node in ipairs(childs) do
      local is_last = i == #childs
      local connector = is_last and "└─ " or "├─ "
      local linenr = #lines
      local prefix_len = #connector + #prefix
      local icon = M.icon_from_node(node.type)
      local icon_group = highlights.group_from_node(node.type)
      local node_type = node.type or "PackedScene"
      local icon_end = prefix_len + #icon + 1
      local node_name_end = icon_end + #node.name
      local type_start = node_name_end + 2
      local type_end = type_start + 2 + #node_type -- -1

      -- rel lines
      hl_spans[#hl_spans + 1] = { line = linenr, col_beg = 0, col_end = prefix_len, group = "GDToolsSceneTreeRelLine" }
      -- icon
      hl_spans[#hl_spans + 1] = { line = linenr, col_beg = prefix_len, col_end = icon_end, group = icon_group }
      -- node name
      hl_spans[#hl_spans + 1] = { line = linenr, col_beg = icon_end, col_end = node_name_end, group = "GDToolsSceneTreeNormal" }

      if opts.always_show_type or node_type != node.name then
        -- node type
        hl_spans[#hl_spans + 1] = { line = linenr, col_beg = type_start, col_end = type_end, group = "GDToolsNodeType" }
        lines[#lines + 1] = ("%s%s%s %s  [%s]"):format(prefix, connector, icon, node.name, node_type)
      else
        lines[#lines + 1] = ("%s%s%s %s"):format(prefix, connector, icon, node.name)
      end

      local next_prefix = prefix .. (is_last and "  " or "│  ")
      if depth < opts.max_depth then
        walk(node_name .. "/" .. node.name, depth + 1, next_prefix)
      end
    end
  end

  local root_icon = M.icon_from_node(root.type)
  local icon_end = #root_icon + 1
  local name_end = icon_end + #root.name
  local type_start = name_end + 2
  local type_end = type_start + #root.type + 2
  -- icon
  hl_spans[1] = { line = 0, col_beg = 0, col_end = icon_end, group = highlights.group_from_node(root.type) }
  -- root name
  hl_spans[2] = { line = 0, col_beg = icon_end, col_end = name_end, group = "GDToolsSceneTreeNormal" }
  if opts.always_show_type or root.type != root.name then
    -- root type
    hl_spans[3] = { line = 0, col_beg = type_start, col_end = type_end, group = "GDToolsNodeType" }
    lines[1] = ("%s %s  [%s]"):format(root_icon, root.name, root.type)
  else
      lines[#lines + 1] = ("%s %s"):format(root_icon, root.name)
  end
  walk("", 1, "")
  return lines, hl_spans
end


return M
