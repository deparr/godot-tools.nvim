local M = {}

---@param opts gdtools.Config? user supplied config
function M.setup(opts)
  local config = require "godot-tools.config"
  config.setup(opts)

  if config.auto_connect then
    -- todo this might be best run in a autocmd, especially if the plugin needs more
    -- things to run on startup
    vim.schedule(function()
      require("godot-tools.editor").connect()
    end)
  end
end

return M
