local M = {}

M.root = nil

function M.update_project_root()
  M.root = vim.fs.root(0, "project.godot")
end

do
  M.update_project_root()
end

return M
