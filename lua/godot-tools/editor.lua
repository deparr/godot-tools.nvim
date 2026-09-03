local log = require "godot-tools.log"

local M = {}

---@param ctx gdtools.Command.Context
function M.open(ctx)
  local file_name_abs = ctx.args[1]
  local file_name = vim.fn.fnamemodify(file_name_abs, ":p:.")
  local file_line = math.floor(tonumber(ctx.args[2]) or 1)
  local file_col = math.floor(tonumber(ctx.args[3]) or 1)

  ---@type integer
  local target_buf
  ---@type integer
  local target_win

  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bufname = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":p:.")
    bufname = bufname:gsub("%\\", "/")
    if file_name == bufname then
      target_win = win
      target_buf = buf
      break
    end
  end

  if target_win ~= nil then
    vim.api.nvim_set_current_win(target_win)
  else
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf) then
        local bufname = vim.api.nvim_buf_get_name(buf)
        if file_name == bufname then
          target_buf = buf
          break
        end
      end
    end

    if target_buf ~= nil then
      vim.cmd "botright vsplit"
      vim.api.nvim_set_current_buf(target_buf)
    else
      vim.cmd("botright vsplit " .. file_name)
    end
    target_win = vim.api.nvim_get_current_win()
  end

  vim.api.nvim_win_set_cursor(target_win, { file_line, file_col })
end

---@param ctx gdtools.Command.Context
function M.connect(ctx)
  local remote_addr = ctx.args[1] or "127.0.0.1:6004"
  local connected_servers = vim.fn.serverlist()
  if vim.list_contains(connected_servers, remote_addr) then
    log.info("already connected to %s!", remote_addr)
    return
  end
  local actual_addr = vim.fn.serverstart(remote_addr)
  if actual_addr then
    log.info("connected to %s", actual_addr)
  end
end

return M
