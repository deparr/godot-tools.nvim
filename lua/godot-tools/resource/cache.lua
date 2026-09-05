local M = {}

---@type integer
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

return M
