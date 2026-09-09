local M = {}
local highlights = require "godot-tools.highlights"

M.ns_id = vim.api.nvim_create_namespace "godot-tools"

M.icons = {
  node = "○",
  scene = "●",
  script = "$",
  scene_indicator = "N",
  unique = "%",
  signal = "@",
}

--[[ consider emoji icons
M.icons = {
  node = "○",
  scene = "●",
  script = "📜",
  scene_indicator = "🎬",
  unique = "",
  signal = "📡"
}
--]]

--[[ consider nerdfont icons
M.icons = {
  node = "○",
  scene = "●",
  script = "󰯁",
  scene_indicator = "󰿎",
  unique = "",
  signal = "󰘊"
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

---@class gdtools.Render.Context
---@field lines string[]
---@field hls gdtools.HLSpan[]
---@field scene gdtools.Scene
---@field opts gdtools.Render.opts
---@field node_path string

---@param opts gdtools.Render.opts
---@param name string node name
---@param type string node type
---@return boolean
function should_render_type(opts, name, type)
  return opts.show_type == "always" or (opts.show_type == "auto" and name ~= type)
end

---@param ctx gdtools.Render.Context
---@param node gdtools.Node
---@return boolean
function node_has_connection(ctx, node)
  if #ctx.scene.conns == 0 then
    return false
  end
  local path = ctx.node_path:sub(2)
  return vim.iter(ctx.scene.conns):fold(false, function(acc, x)
    return acc or x.from == path
  end)
end

---@param ctx gdtools.Render.Context
---@param node gdtools.Node
---@return string
function node_indicators(ctx, node)
  -- todo visible indicators? its already pretty noisy
  local unique = node.values.unique_name_in_owner and M.icons.unique or ""
  local signal = node_has_connection(ctx, node) and M.icons.signal or ""
  -- I think using the path as type + filled in icon is enough
  -- local scene = node.instance and M.icons.scene_indicator or ""
  local script = node.values.script and M.icons.script or ""
  local spacer = math.max(#unique, #signal, #script) > 0 and "  " or ""
  return ("%s%s%s%s"):format(spacer, unique, signal, script)
end

---@param ctx gdtools.Render.Context
---@param node gdtools.Node
---@return string
function scene_path(ctx, node)
  if not node.instance or node.instance._tag ~= "call" then
    return ""
  end

  local res_id = node.instance.args[1]
  local ext_scene = vim
    .iter(ctx.scene.ext_resources)
    :filter(function(x)
      return x.id == res_id
    end)
    :totable()[1]

  if not ext_scene then
    return ""
  end

  return ext_scene.path
end

---@param ctx gdtools.Render.Context
---@param node gdtools.Node
---@param prefix string
---@param connector string
function render_node(ctx, node, prefix, connector)
  local lines = ctx.lines
  local linenr = #lines
  local hls = ctx.hls
  local prefix_len = #connector + #prefix
  local icon = M.icon_from_node(node.type)
  local icon_group = highlights.group_from_node(node.type)
  local indicators = ctx.opts.show_indicators and node_indicators(ctx, node) or ""
  local node_type = node.type or scene_path(ctx, node)
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

  if should_render_type(ctx.opts, node.name, node_type) then
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
  local ctx = {
    lines = lines,
    hls = hl_spans,
    scene = scene,
    node_path = ".",
    opts = opts,
  }
  -- todo don't really like this, would rather not create a function each time
  local function walk(node_name, depth, prefix)
    local childs = children[node_name] or {}
    for i, node in ipairs(childs) do
      local is_last = i == #childs
      local connector = is_last and "└─ " or "├─ "
      local full_path = node_name .. "/" .. node.name
      ctx.node_path = full_path
      render_node(ctx, node, prefix, connector)

      local next_prefix = prefix .. (is_last and "   " or "│  ")
      if depth < opts.max_depth then
        walk(full_path, depth + 1, next_prefix)
      end
    end
  end

  render_node(ctx, root, "", "")
  walk("", 1, "")
  return lines, hl_spans
end

return M
