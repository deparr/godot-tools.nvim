local default_config = {
  godot_bin = (vim.fn.has "win32" == 1) and "godot_console" or "godot",
  editor = {
    auto_connect = true,
    listen_addr = "127.0.0.1:6004",
  },
}

---@class gdtools.Config
---@field godot_bin string path to godot binary
---@field editor gdtools.Config.Editor
local M = {}

---@class gdtools.Config.Editor
---@field auto_connect boolean whether to start the server at startup
---@field listen_addr string where to listen for remote events, can be an ip addr or named pipe

---@param opts gdtools.Config? user supplied config
function M.setup(opts)
  opts = opts or {}
  opts = vim.tbl_deep_extend("keep", opts, default_config)

  if opts.setup then
    opts.setup = nil
  end

  for k, v in pairs(opts) do
    M[k] = v
  end
end

setmetatable(M, {
  __index = default_config,
})

return M
