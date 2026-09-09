local Parser = require "godot-tools.resource.parser"
local log = require "godot-tools.log"

local cache = require "godot-tools.resource.cache"

local M = {}

---@param path string path to load from
---@param expected_type string? expected type of loaded resource
---@return gdtools.Resource?
function M.load(path, expected_type)
  local cached = cache.get(path)
  if cached then
    return cached
  end
  local f = io.open(path, "r")
  if not f then
    error(("failed to open file: %s"):format(path))
  end
  local source = f:read "a"
  local resource = M.load_str(source, expected_type)
  if resource then
    cache.set(path, resource)
  end
  return resource
end

---@param source string source to load from
---@param expected_type? string expected type of loaded resource
---@return gdtools.Resource?
function M.load_str(source, expected_type)
  local ok, result = pcall(Parser.parse_resource, source)
  if not ok then
    log.error("parsing resource: %s", result)
    return
  end
  return result
end

---@param path string path to load from
---@return gdtools.Scene?
function M.load_scene(path)
  local cached = cache.get(path)
  if cached then
    return cached
  end
  local f = io.open(path, "r")
  if not f then
    error(("failed to open file: %s"):format(path))
  end
  local source = f:read "a"
  f:close()
  local scene = M.load_scene_str(source)
  if scene then
    cache.set(path, scene)
  end
  return scene
end

--- The cache is keyed by path so this function will always
--- reparse `source`
---@param source string string to load from
---@return gdtools.Scene?
function M.load_scene_str(source)
  local ok, result = pcall(Parser.parse_scene, source)
  if not ok then
    log.error("parsing scene: %s", result)
    return
  end
  return result
end

--- This **does not** convert uid:// 's into res:// paths,
--- it will throw if given one
---@param real_path string absolute or relative path to a project resource
---@return string res_path res:// prefixed path to resource at `real_path`
function M.path(real_path)
  real_path = real_path or ""
  if vim.startswith(real_path, "res://") then
    return real_path
  elseif vim.startswith(real_path, "uid://") then
    error(("%s is already a uid"):format(real_path)) -- error, this is a bug
  end

  -- todo this hsould use the found project directory instead of cwd()
  return "res://" .. vim.fs.relpath(vim.fn.getcwd(), vim.fs.normalize(vim.fs.abspath(real_path)))
end

function M.health_check()
  local cached, timer_active = cache.stats()
  if timer_active then
    vim.health.ok "Cache clean timer is active"
  else
    vim.health.warn "Cache clean timer is NOT active. Cache will not be pruned automatically"
  end
  vim.health.info(("Cache Keys (%d):"):format(#cached))
  for _, p in ipairs(cached) do
    vim.health.info(p)
  end
end

return M
