local M = {}

function M.check()
  vim.health.start "godot"
  vim.health.info "todo health checks"
end

return M
