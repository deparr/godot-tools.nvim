local M = {}

---@type gdtools.Resource.Ref?
M.main_scene = nil
---@type string?
M.root = nil

function M.update_root()
  M.root = vim.fs.root(0, "project.godot")
  M.root = M.root and vim.fs.normalize(M.root) or nil
end

--- Reparses the `project.godot` file to extract
--- project info
function M.update_info()
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
    log.error("project.godot parse error: %s", res)
    return
  end

  if res.application then
    local main_ref = res.application["run/main_scene"]
    if main_ref then
      M.main_scene = vim.startswith(main_ref, "uid://") and { uid = main_ref } or { path = main_ref }
    end
  end
  -- log.info "updated project info"
end

local watch_state = {
  ---@type "inactive"|"active"|"error"
  status = "inactive",
  ---@type string?
  last_error = nil,
  started_at = 0,
  last_event_at = 0,
  ---@type fun()?
  cancel = nil,
}

function M.health_check()
  vim.health.info("Current project: " .. (M.root or "<none>"))
  local main_ref = M.main_scene and (M.main_scene.uid or M.main_scene.path) or "<no main scene>"
  vim.health.info("Main Scene: " .. main_ref)

  if watch_state.status == "inactive" then
    vim.health.info 'NOT watching project.godot for changes\n  to start: `require("godot-tools.project").start_watch()`'
  elseif watch_state.status == "active" then
    local msg =
      'Watching project.godot for changes\n  Last Change: %ds ago\n  to stop: `require("godot-tools.project").stop_watch()`'
    vim.health.info(msg:format(os.time() - watch_state.last_event_at))
  elseif watch_state.status == "error" then
    vim.health.warn(
      ("Error starting uv watch: %s"):format(watch_state.last_error),
      "consider filing an issue at https://github.com/deparr/godot-tools.nvim"
    )
  else
    vim.health.error(
      "watch_state.status is invalid, this is probably a bug with godot-tools.nvim",
      "consider filing an issue at https://github.com/deparr/godot-tools.nvim"
    )
  end
end

--- Start a file watch on 'project.godot' and
--- call M.update_project_info() on changes
function M.start_watch()
  local log = require "godot-tools.log"
  if not M.root then
    log.warn "no root to watch!"
    return
  end
  local uv = vim.uv
  local handle, _, handlerr = uv.new_fs_event()
  local debounce, _, timererr = uv.new_timer()

  if not handle or not debounce then
    log.error "Unable to create watch event see health check"
    watch_state.status = "error"
    watch_state.last_error = handleerr or timererr
    return
  end

  local _, start_err, start_errname = handle:start(M.root, {}, function(err, filename, events)
    if filename ~= "project.godot" then
      return
    end
    watch_state.last_event_at = os.time()
    debounce:start(400, 0, M.update_info)
  end)

  if start_err then
    log.error "Unable to start watching, see health check"
    watch_state.status = "error"
    watch_state.last_error = start_errname
    handle:close()
    debounce:close()
    return
  end

  watch_state.status = "active"
  watch_state.started_at = os.time()
  watch_state.last_event_at = watch_state.started_at
  watch_state.cancel = function()
    local _, stop_err = handle:stop()
    assert(not stop_err, stop_err)
    local is_closing, close_err = handle:is_closing()
    assert(not close_err, close_err)
    if not is_closing then
      handle:close()
    end
    debounce:stop()
    debounce:close()
    watch_state.status = "inactive"
    watch_state.cancel = nil
  end
end

function M.stop_watch()
  if watch_state.status ~= "active" then
    return
  end
  if not watch_state.cancel then
    log.error "watch_state is active but cancel fn is nil, this is a bug"
    return
  end
  watch_state.cancel()
end

do
  M.update_root()
  M.update_info()
end

return M
