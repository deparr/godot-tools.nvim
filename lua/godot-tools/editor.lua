local config = require "godot-tools.config"
local log = require "godot-tools.log"

local M = {}

---@param path string file to open
---@param line string? line to move to
---@param col string? col to move to
function M.open(path, line, col)
  local file_name = vim.fn.fnamemodify(path, ":p:.")
  local file_line = math.floor(tonumber(line) or 1)
  local file_col = math.floor(tonumber(col) or 1)

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

---@param listen_addr string? address to listen for godot editor calls on
function M.connect(listen_addr)
  listen_addr = listen_addr or config.editor.listen_addr
  if M.is_connected_to(listen_addr) then
    log.info("already connected to %s!", listen_addr)
    return
  end
  local ok, result = pcall(vim.fn.serverstart, listen_addr)
  if not ok then
    log.error("unable to connect to %s: %s", listen_addr, result)
  else
    if result then
      log.info("connected to %s", listen_addr)
    end
  end
end

---@param listen_addr string ip4 addr or named pipe
---@return boolean true if nvim is already listening on listen_addr
function M.is_connected_to(listen_addr)
  return vim.list_contains(vim.fn.serverlist(), listen_addr)
end

function M.health_check()
  local function check_ip(addr)
    local a, b, c, d, p = addr:match "^(%d+)%.(%d+)%.(%d+)%.(%d+)%:(%d+)$"
    if not a then
      return false
    end
    a, b, c, d, p = tonumber(a), tonumber(b), tonumber(c), tonumber(d), tonumber(p)
    for _, octet in ipairs({ a, b, c, d }) do
      if (octet or 256) > 255 then
        return false
      end
    end
    if (p or 65536) > 65535 then
      return false
    end
    return true
  end
  local config = require "godot-tools.config"
  local listen_addr = config.editor.listen_addr
  local addr_is_valid = listen_addr ~= nil
  if listen_addr and listen_addr:find ":" then
    addr_is_valid = check_ip(listen_addr)
  end
  if not addr_is_valid then
    vim.health.warn(("'%s' is not a valid ip4 address. will be unable to connect to Godot"):format(listen_addr))
  else
    if require("godot-tools.editor").is_connected_to(listen_addr) then
      vim.health.ok(("connected to: %s"):format(listen_addr))
    else
      vim.health.ok(("'%s' is a valid address"):format(listen_addr))
    end
  end
end

return M
