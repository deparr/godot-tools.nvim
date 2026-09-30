local default_config = {
  run = {
    bin = "godot",
    bin_console = (vim.fn.has "win32" == 1) and "godot_console" or "godot",
  },
  editor = {
    auto_connect = true,
    listen_addr = "127.0.0.1:6004",
  },
  project = {
    auto_watch = false,
  },
}

---@class gdtools.Config
---@field run gdtools.Config.Run
---@field editor gdtools.Config.Editor
---@field project gdtools.Config.Project
local M = {}

---@class gdtools.Config.Run
---@field bin string path to godot binary
---@field bin_console string path to godot_console binary, used on windows

---@class gdtools.Config.Editor
---@field auto_connect boolean whether to start the server at startup
---@field listen_addr string where to listen for remote events, can be an ip addr or named pipe

---@class gdtools.Config.Project
---@field auto_watch boolean whether to start a libuv on project.godot

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
