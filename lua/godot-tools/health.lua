local M = {}

function M.check()
  vim.health.start "Run"
  require("godot-tools.run").health_check()

  vim.health.start "Editor"
  require("godot-tools.editor").health_check()

  vim.health.start "Project"
  require("godot-tools.project").health_check()

  vim.health.start "Resources"
  require("godot-tools.resource").health_check()
end

return M
