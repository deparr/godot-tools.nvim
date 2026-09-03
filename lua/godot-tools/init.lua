local M = {}

-- todo proper config manangement and typing
M.config = {
  godot_bin = require("util").is_windows and "godot_console" or "godot",
  set_keymaps = true,
  auto_connect = true,
  godot_addr = "127.0.0.1:6004",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if M.config.auto_connect then
    -- todo this might be best run in a autocmd, especially if the plugin needs more
    -- things to run on startup
    vim.schedule(function()
      require("godot-tools.editor").connect { args = { M.config.godot_addr } }
    end)
  end
end

return M
