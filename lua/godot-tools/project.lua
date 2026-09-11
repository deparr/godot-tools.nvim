local M = {}
M.main_scene = nil
M.root = nil

function M.update_project_root()
  M.root = vim.fs.root(0, "project.godot")
end

-- todo dont like this
-- replace this with a real parser and uv file watcher
---@return string main_scene uid/res path
local function extract_main()
  local path = vim.fs.joinpath(M.root, "project.godot")
  local f = io.open(path, "r")
  if not f then
    return ""
  end

  for line in f:lines() do
    local match = line:match 'run/main_scene.*=.*%"(uid://.*)%"'
    if match then
      f:close()
      return match
    end
  end
  f:close()
  error("unable to find main scene in " .. path)
end

--- Reparses the `project.godot` file to extract
--- project info
function M.update_project_info()
  local log = require "godot-tools.log"
  if not M.root then
    log.error "No project root!"
    return
  end

  local project_file = vim.fs.joinpath(M.root, "project.godot")
  local f, err = io.open(project_file, "r")
  if not f then
    log.error("Unable to open project.godot: %s", err)
    return
  end

  local config_source = f:read "a"
  f:close()

  local Parser = require "godot-tools.project.parser"
  local ok, res = pcall(Parser.parse, config_source)
  if not ok then
    log.error("Unable to parse project.godot: %s", res)
    return
  end

  if res.application then
    local main_ref = res.application["run/main_scene"]
    if main_ref then
      M.main_scene = vim.startswith(main_ref, "uid://") and { uid = main_ref } or { path = main_ref }
    end
  end
end

function M.health_check()
  vim.health.info("Current project: " .. (M.root or "<none>"))
  local main_ref = M.main_scene and (M.main_scene.uid or M.main_scene.path) or "<no main scene>"
  vim.health.info("Main Scene: " .. main_ref)
end

do
  M.update_project_root()
end

return M
