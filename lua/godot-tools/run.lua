local M = {}

local config = require "godot-tools.config"
local log = require "godot-tools.log"

local api = vim.api

---@class gdtools.Run.State
M.state = {
  ---@type gdtools.Resource.Ref
  last_scene = nil,
  ---@type integer
  console_buf = -1,
  ---@type integer
  console_win = -1,
  ---@type table<number, { argv: string[], pid: integer }
  jobs = {},
}

--- Run the project's main scene
function M.main()
  M.scene({ uid = require("godot-tools.project").main_scene })
end

--- Run the last scene run with M.scene
---@param ref? gdtools.Resource.Ref
function M.last(ref)
  if not M.state.last_scene then
    if not ref then
      log.error "no last scene to run!"
      return
    end
    M.state.last_scene = ref
  end
  M.scene(M.state.last_scene)
end

--- Run a specific scene
---@param ref gdtools.Resource.Ref
function M.scene(ref)
  if not ref then
    log.error "need a scene to run!"
    return
  end

  local scene_id = ref.uid or ref.path
  if not scene_id then
    log.error "ref has no data"
    return
  end

  local project = require "godot-tools.project"
  if not project.root then
    log.error "project root is missing. not running scene"
    return
  end

  -- clean up our old buffer and win
  if api.nvim_buf_is_valid(M.state.console_buf) then
    api.nvim_buf_delete(M.state.console_buf, { force = true })
  end
  M.state.console_buf = api.nvim_create_buf(true, false)

  if not api.nvim_win_is_valid(M.state.console_win) then
    vim.cmd "bot split"
    M.state.console_win = api.nvim_get_current_win()
    api.nvim_win_resize(M.state.console_win, -1, 20, { anchor = "bottom" })
  else
    api.nvim_set_current_win(M.state.console_win)
  end
  api.nvim_win_set_buf(M.state.console_win, M.state.console_buf)

  vim.bo.filetype = "gdtools-console"
  api.nvim_set_option_value("scrolloff", 999, { win = M.state.console_win, scope = "local" })

  local argv = { config.godot_bin, "--path", project.root, "--scene", scene_id }
  local id
  id = vim.fn.jobstart(argv, {
    term = true,
    on_exit = function()
      M.state.jobs[id] = nil
    end,
  })

  if id > 0 then
    vim.cmd "startinsert"
    M.state.jobs[id] = { argv = argv, pid = vim.fn.jobpid(id) }
    M.state.last_scene = ref
  else
    log.error("unable to run godot: " .. (id == -1 and "invaild job args" or "cmd[0] is not executable"))
  end
end

--- Opens `require("godot-tools.project").root` in the godot editor
function M.editor()
  local project = require "godot-tools.project"
  if not project.root then
    log.error "project root is missing, not opening editor"
    return
  end
  local project_godot = vim.fs.joinpath(project.root, "project.godot")
  local args = { config.godot_bin, "--edit", project_godot }

  vim.system(args, { detach = true, cwd = project.root })
end

--- toggles visibility of the godot console buffer
function M.toggle_console()
  if not api.nvim_buf_is_valid(M.state.console_buf) then
    log.warn("bufnr %d is invalid", M.state.console_buf)
    return
  end

  if api.nvim_win_is_valid(M.state.console_win) then
    api.nvim_win_close(M.state.console_win, false)
  else
    vim.cmd "bot split"
    M.state.console_win = api.nvim_get_current_win()
    api.nvim_win_resize(M.state.console_win, -1, 20, { anchor = "bottom" })
    api.nvim_win_set_buf(M.state.console_win, M.state.console_buf)
  end
end

function M.health_check()
  if vim.fn.executable(config.godot_bin) == 0 then
    vim.health.warn(("'%s' is not executable."):format(config.godot_bin))
  else
    vim.health.ok(("%s is executable"):format(config.godot_bin))
  end

  if #vim.tbl_keys(M.state.jobs) > 0 then
    vim.health.info "Jobs:"
    for _, job in pairs(M.state.jobs) do
      vim.health.info(("PID %d: %s"):format(job.pid, table.concat(job.argv, " ")))
    end
  else
    vim.health.info "No active jobs"
  end
end

return M
