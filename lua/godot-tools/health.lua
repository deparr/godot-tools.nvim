local M = {}

---@param addr string ip4 address to check
---@return boolean valid addr is a valid ip4 address
local function check_ip(addr)
  local a, b, c, d, p = addr:match "^(%d+)%.(%d+)%.(%d+)%.(%d+)%:(%d+)$"
  if not a then
    return false
  end
  a, b, c, d, p =
    math.floor(tonumber(a)),
    math.floor(tonumber(b)),
    math.floor(tonumber(c)),
    math.floor(tonumber(d)),
    math.floor(tonumber(p))
  for _, octet in ipairs({ a, b, c, d }) do
    if octet > 255 then
      return false
    end
  end
  if p > 65535 then
    return false
  end
  return true
end

function M.check()
  vim.health.start "godot-tools"

  local config = require("godot-tools.config")
  if vim.fn.executable(config.godot_bin) == 0 then
    vim.health.warn(("'%s' is not executable, godot-tools.run commands will fail"):format(config.godot_bin))
  else
    vim.health.ok(("%s is exescutable"):format(config.godot_bin))
  end

  local addr_is_valid = true
  local listen_addr = config.editor.listen_addr
  if listen_addr then
    addr_is_valid = check_ip(listen_addr)
  end
  if not addr_is_valid then
    vim.health.warn(("'%s' is not a valid ip4 address. will be unable to connect to Godot"):format(listen_addr)
  else
    vim.health.ok(("'%s' is a valid listen address"):format(listen_addr)
  end
end

return M
