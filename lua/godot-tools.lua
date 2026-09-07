local M = {}

---@param opts gdtools.Config? user supplied config
function M.setup(opts)
  local config = require "godot-tools.config"
  config.setup(opts)
end

return M
