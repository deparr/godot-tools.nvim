local M = {}

local config = require("godot-tools").config
local log = require "godot-tools.log"

local api = vim.api

M.state = {
  ---@type string?
  main_scene = nil,
  ---@type string?
  last_scene = nil,
  console_buf = -1,
  console_win = -1,
}

local extract_main_uid = require("util").extractor 'run/main_scene.*=.*%"(uid://.*)%"'

--@param ctx GDToolsCommandContext
function M.main(ctx)
  if not M.state.main_scene then
    -- todo this sucks
    local project_file = vim.fs.joinpath(vim.fn.getcwd(), "project.godot")
    M.state.main_scene = extract_main_uid(project_file)
    if not M.state.main_scene then
      log.error "unable to find main scene"
      return
    end
  end
  ctx.args = { M.state.main_scene }
  M.scene(ctx)
end

--@param ctx GDToolsCommandContext
function M.last(ctx)
  if not M.state.last_scene then
    if #ctx.args < 1 then
      log.error "no last scene to run!"
      return
    end
    M.state.last_scene = ctx.args[1]
  end
  ctx.args = { M.state.last_scene }
  M.scene(ctx)
end

--@param ctx GDToolsCommandContext
function M.scene(ctx)
  if #ctx.args < 1 then
    log.error "need a scene to run!"
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

  if ctx.args[1] ~= M.state.main_scene then
    M.state.last_scene = ctx.args[1]
  end

  vim.bo.filetype = "godot-console"
  api.nvim_set_option_value("scrolloff", 999, { win = M.state.console_win, scope = "local" })
  vim.fn.jobstart({ config.godot_bin, "--scene", ctx.args[1] }, { term = true })
  vim.cmd "startinsert"
end

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
