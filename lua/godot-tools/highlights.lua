local M = {}

---@type table<"light"|"dark", table<string, vim.api.keyset.set_hl_info>>
M.defs = {
  dark = {
    GDToolsNode = { fg = "#e0e0e0", ctermfg = "white", default = true },
    GDToolsNode2D = { fg = "#6393ff", ctermfg = "blue", default = true },
    GDToolsNode3D = { fg = "#ff5555", ctermfg = "red", default = true },
    GDToolsNodeControl = { fg = "#6aff7c", ctermfg = "green", default = true },
    GDToolsNodeAnimation = { fg = "#c55bff", ctermfg = "magenta", default = true },
    GDToolsNodeEditor = { fg = "#ffcb77", ctermfg = "yellow", default = true },
    GDToolsNodeIndicator = { link = "Normal" },
    GDToolsNodeType = { link = "Comment", default = true },
    GDToolsSceneTreeNormal = { link = "Normal" },
    GDToolsSceneTreeRelLine = { link = "WinSeparator", default = true },
  },
  light = {
    GDToolsNode = { fg = "#5a5a5a", ctermfg = "black", default = true },
    GDToolsNode2D = { fg = "#3d64dd", ctermfg = "blue", default = true },
    GDToolsNode3D = { fg = "#cd3838", ctermfg = "red", default = true },
    GDToolsNodeControl = { fg = "#2fa139", ctermfg = "green", default = true },
    GDToolsNodeAnimation = { fg = "#a85de9", ctermfg = "magenta", default = true },
    GDToolsNodeEditor = { fg = "#844b0e", ctermfg = "yellow", default = true },
    GDToolsNodeType = { link = "Comment", default = true },
    GDToolsNodeIndicator = { link = "Normal" },
    GDToolsSceneTreeNormal = { link = "Normal" },
    GDToolsSceneTreeRelLine = { link = "WinSeparator", default = true },
  },
}

---@type table<string, string>?
local node_to_group = nil

---@param type string godot node type
---@return string # hl group name
function M.group_from_node(type)
  if not node_to_group then
    node_to_group = require "godot-tools.highlights.groupmap"
  end
  return node_to_group[type] or "GDToolsNode"
end

function M.setup_highlights()
  local hls = M.defs[vim.o.bg]
  for group, def in pairs(hls) do
    vim.api.nvim_set_hl(0, group, def)
  end
end

do
  M.setup_highlights()
  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("gdtools.highlight", {}),
    callback = M.setup_highlights,
  })
end

return M
