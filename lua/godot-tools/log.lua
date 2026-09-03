local M = {}

M.prefix = "godot"

local function notify(level, fmt, ...)
  vim.notify(("%s: %s"):format(M.prefix, fmt:format(...)), level)
end

M.error = function(fmt, ...)
  notify(vim.log.levels.ERROR, fmt, ...)
end

M.warn = function(fmt, ...)
  notify(vim.log.levels.WARN, fmt, ...)
end

M.info = function(fmt, ...)
  notify(vim.log.levels.INFO, fmt, ...)
end

return M
