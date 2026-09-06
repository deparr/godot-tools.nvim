local M = {}
local highlights = require "godot-tools.highlights"

M.ns_id = vim.api.nvim_create_namespace "godot-tools"

M.icons = {
  node = "○",
  scene = "●",
  script = "$",
  scene_indicator = "N",
  unique = "%",
}

--[[ consider emoji icons
M.icons = {
  node = "○",
  scene = "●",
  script = "📜",
  scene_indicator = "🎬",
  unique = "",
}
--]]

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
  show_type = "auto",
  show_indicators = true,
}

---@param opts gdtools.Render.opts
---@param name string node name
---@param type string node type
---@return boolean
function should_render_type(opts, name, type)
  return opts.show_type == "always" or (opts.show_type == "auto" and name ~= type)
end

---@param node gdtools.Node
---@return string
function node_indicators(node)
  -- todo visible indicators? its already pretty noisy
  local unique = node.values.unique_name_in_owner and M.icons.unique or ""
  local scene = not node.type and M.icons.scene_indicator or ""
  local script = node.values.script and M.icons.script or ""
  local spacer = (#unique > 0 or #scene > 0 or #script > 0) and "  " or ""
  return ("%s%s%s%s"):format(spacer, unique, scene, script)
end

function render_node(lines, hls, node, prefix, connector, opts)
  local linenr = #lines
  local prefix_len = #connector + #prefix
  local icon = M.icon_from_node(node.type)
  local icon_group = highlights.group_from_node(node.type)
  local indicators = opts.show_indicators and node_indicators(node) or ""
  local node_type = node.type or "PackedScene"
  local icon_end = prefix_len + #icon + 1 -- space after icon
  local node_name_end = icon_end + #node.name
  local indicators_start = node_name_end -- space after node name
  local indicators_end = indicators_start + #indicators
  local type_start = indicators_end + 1 -- space after indicators
  local type_end = type_start + 2 + #node_type -- brackets

  -- rel lines
  hls[#hls + 1] = { line = linenr, col_beg = 0, col_end = prefix_len, group = "GDToolsSceneTreeRelLine" }
  -- icon
  hls[#hls + 1] = { line = linenr, col_beg = prefix_len, col_end = icon_end, group = icon_group }
  -- node name
  hls[#hls + 1] = { line = linenr, col_beg = icon_end, col_end = node_name_end, group = "GDToolsSceneTreeNormal" }
  hls[#hls + 1] =
    { line = linenr, col_beg = indicators_start, col_end = indicators_end, group = "GDToolsNodeIndicator" }

  if should_render_type(opts, node.name, node_type) then
    -- node type
    hls[#hls + 1] = { line = linenr, col_beg = type_start, col_end = type_end, group = "GDToolsNodeType" }
    lines[#lines + 1] = ("%s%s%s %s%s [%s]"):format(prefix, connector, icon, node.name, indicators, node_type)
  else
    lines[#lines + 1] = ("%s%s%s %s%s"):format(prefix, connector, icon, node.name, indicators)
  end
end

---@class gdtools.HLSpan
---@field line integer
---@field col_beg integer
---@field col_end integer
---@field group string

---@param scene gdtools.Scene
---@param opts gdtools.Render.opts?
---@return string[] lines, gdtools.HLSpan[] hl_spans
function M.scene_tree(scene, opts)
  opts = vim.tbl_deep_extend("force", default_render_opts, opts or {})

  local root = nil
  local children = {}
  for _, node in ipairs(scene.nodes) do
    if not node.parent then
      root = node
    else
      local parent
      if node.parent == "." then
        parent = ""
      else
        parent = "/" .. node.parent
      end
      children[parent] = children[parent] or {}
      children[parent][#children[parent] + 1] = node
    end
  end

  local lines = {}
  local hl_spans = {}
  -- todo don't really like this, would rather not create a function each time
  local function walk(node_name, depth, prefix)
    local childs = children[node_name] or {}
    for i, node in ipairs(childs) do
      local is_last = i == #childs
      local connector = is_last and "└─ " or "├─ "
      render_node(lines, hl_spans, node, prefix, connector, opts)

      local next_prefix = prefix .. (is_last and "   " or "│  ")
      if depth < opts.max_depth then
        walk(node_name .. "/" .. node.name, depth + 1, next_prefix)
      end
    end
  end

  render_node(lines, hl_spans, root, "", "", opts)
  walk("", 1, "")
  return lines, hl_spans
end

return M
