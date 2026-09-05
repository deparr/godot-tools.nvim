local Parser = require "godot-tools.resource.parser"
local log = require "godot-tools.log"

local cache = require "godot-tools.resource.cache"

local M = {}

---@enum Tag known tags for resource blocks
local Tag = {
  ROOT_RESOURCE = "gd_resouce",
  ROOT_SCENE = "gd_scene",
  SUB_RESOURCE = "sub_resource",
  EXT_RESOURCE = "ext_resource",
  NODE = "node",
  RESOURCE = "resource",
}

---@param path string path to load from
---@param expected_type string? expected type of loaded resource
---@return gdtools.Resource
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
  return M.load_str(source, expected_type)
end

---@param source string source to load from
---@param expected_type? string expected type of loaded resource
---@return gdtools.Resource
function M.load_str(source, expected_type)
  local parser = Parser.new(source)
  local res, sub_resources = {}, {}
  res.sub_resources = sub_resources
  local found_main_tag = false
  for block in parser:block_stream() do
    if block.tag == Tag.ROOT_RESOURCE then
      found_main_tag = true
      res.type = block.attrs.type
      res.format = block.attrs.format
      res.uid = block.attrs.uid
    elseif block.tag == Tag.SUB_RESOURCE then
      local sub_res = {
        type = block.attrs.type,
        id = block.attrs.id,
        values = block.values,
      }
      sub_resources[#res.sub_resources + 1] = sub_res
    elseif block.tag == Tag.RESOURCE then
      res.values = block.values
    else
      log.warn(("TODO unexpected block.tag in resource: %s"):format(block.tag))
    end
  end

  if not found_main_tag then
    log.error "Did not find main tag for resource"
  end

  return res
end

---@param path string path to load from
---@return gdtools.Scene
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
  return M.load_scene_str(source)
end

---@param source string string to load from
---@return gdtools.Scene
function M.load_scene_str(source)
  local parser = Parser.new(source)
  local scene, ext_resources, sub_resources, nodes = {}, {}, {}, {}
  scene.ext_resources = ext_resources
  scene.sub_resources = sub_resources
  scene.nodes = nodes
  local found_main_tag = false
  for block in parser:block_stream() do
    if block.tag == Tag.ROOT_SCENE then
      found_main_tag = true
      scene.format = block.attrs.format
      scene.uid = block.attrs.uid
    elseif block.tag == Tag.EXT_RESOURCE then
      local ext_res = {
        type = block.attrs.type,
        uid = block.attrs.uid,
        path = block.attrs.path,
        id = block.attrs.id,
      }
      ext_resources[#ext_resources + 1] = ext_res
    elseif block.tag == Tag.SUB_RESOURCE then
      local sub_res = {
        type = block.attrs.type,
        id = block.attrs.id,
        values = block.values,
      }
      sub_resources[#sub_resources + 1] = sub_res
    elseif block.tag == Tag.NODE then
      local node = {
        name = block.attrs.name,
        type = block.attrs.type,
        parent = block.attrs.parent,
        unique_id = block.attrs.unique_id,
        instance = block.attrs.instance,
        values = block.values,
      }
      nodes[#nodes + 1] = node
    else
      log.warn(("TODO unexpected block.tag in scene: %s"):format(block.tag))
    end
  end

  if not found_main_tag then
    log.error "Did not find main tag for scene"
  end

  return scene
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

return M
