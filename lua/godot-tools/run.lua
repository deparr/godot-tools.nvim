local M = {}

local config = require "godot-tools.config"
local log = require "godot-tools.log"

local api = vim.api

---@class gdtools.Run.State
M.state = {
  ---@type string? uid of main scene
  main_scene = nil,
  ---@type gdtools.Resource.Ref
  last_scene = nil,
  ---@type integer
  console_buf = -1,
  ---@type integer
  console_win = -1,
}

local extract_main_uid = require("godot-tools.util").extractor 'run/main_scene.*=.*%"(uid://.*)%"'

--- Run the project's main scene
function M.main()
  -- todo this sucks, shouldn't copout with regex or ignore changes to the main scene
  if not M.state.main_scene then
    local project_file = vim.fs.joinpath(vim.fn.getcwd(), "project.godot")
    M.state.main_scene = extract_main_uid(project_file)
    if not M.state.main_scene then
      log.error "unable to find main scene"
      return
    end
  end
  M.scene({ uid = M.state.main_scene })
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

  M.state.last_scene = ref

  vim.bo.filetype = "gdtools-console"
  api.nvim_set_option_value("scrolloff", 999, { win = M.state.console_win, scope = "local" })
  vim.fn.jobstart({ config.godot_bin, "--scene", scene_id }, { term = true })
  vim.cmd "startinsert"
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

return M
