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

do
  setmetatable(M, {
    __index = function(_, k)
      if k == "main_scene" then
        M.main_scene = extract_main()
        return M.main_scene
      end
    end,
  })
  M.update_project_root()
end

return M
