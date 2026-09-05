local M = {}

---@class gdtools.Config
M.config = {
  ---@type string path to godot binary
  godot_bin = (vim.uv.os_uname().sysname:match ".*[wW]indows.*" ~= nil) and "godot_console" or "godot",
  ---@type boolean whether we should auto start the server
  auto_connect = true,
  ---@type string where we should listen for remote events, can be a ip addr or named pipe
  listen_addr = "127.0.0.1:6004",
}

---@param opts gdtools.Config? user supplied config
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
  if M.config.auto_connect then
    -- todo this might be best run in a autocmd, especially if the plugin needs more
    -- things to run on startup
    vim.schedule(function()
      require("godot-tools.editor").connect({ args = { M.config.listen_addr } })
    end)
  end
end

return M
