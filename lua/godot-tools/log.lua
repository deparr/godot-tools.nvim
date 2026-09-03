local M = {}

M.prefix = "godot"

---@param level integer log level
---@param fmt string log format string
---@param ... any format arguments
local function notify(level, fmt, ...)
  vim.notify(("%s: %s"):format(M.prefix, fmt:format(...)), level)
end

---@param fmt string log format string
---@param ... any format arguments
M.error = function(fmt, ...)
  notify(vim.log.levels.ERROR, fmt, ...)
end

---@param fmt string log format string
---@param ... any format arguments
M.warn = function(fmt, ...)
  notify(vim.log.levels.WARN, fmt, ...)
end

---@param fmt string log format string
---@param ... any format arguments
M.info = function(fmt, ...)
  notify(vim.log.levels.INFO, fmt, ...)
end

return M
