local M = {}

---@type integer cache entry lifetime in _seconds_
M.entry_ttl = 60 * 5

---@class gdtools.Resource.Cache.Entry
---@field time integer
---@field data gdtools.Resource | gdtools.Scene

---@type table<string, gdtools.Resource.Cache.Entry>
local entries = {}

---@param key string
---@return (gdtools.Resource|gdtools.Scene)?
function M.get(key)
  local entry = entries[key]
  if not entry or os.time() - entry.time > M.entry_ttl then
    entries[key] = nil
    return nil
  end
  return entry.data
end

---@param key string
---@param data gdtools.Resource|gdtools.Scene
function M.set(key, data)
  entries[key] = {
    time = os.time(),
    data = data,
  }
end

function M.clear_invalid()
  local time = os.time()
  for k, v in pairs(entries) do
    if time - (v.time or 0) > M.entry_ttl then
      entries[k] = nil
    end
  end
end

---@type uv.uv_timer_t
local timer

---@return string[], timer_active boolean
function M.stats()
  return vim.tbl_keys(entries), timer and (timer:is_active())
end

do
  local delay = M.entry_ttl * 2000
  timer = vim.uv.new_timer()
  if timer then
    timer:start(delay, delay, function()
      M.clear_invalid()
    end)
  end
end

return M
