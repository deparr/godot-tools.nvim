local M = {}

---@type fun(lines: string|string[], opts: table?)
M.open_float = vim.schedule_wrap(function(lines, opts)
  if type(lines) == "string" then
    lines = vim.split(lines, "\n")
  end
  opts = opts or {}

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 1, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"

  local max_w = math.floor(vim.o.columns * 0.6)
  local max_h = math.floor(vim.o.columns * 0.8)
  local width = 1
  for _, l in ipairs(lines) do
    width = math.max(width, vim.api.nvim_strwidth(l))
  end
  width = math.min(max_w, width)
  local height = math.min(#lines + 2, max_h)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2) - 1,
    style = opts.style or "minimal",
    border = opts.border or "rounded",
    title = opts.title or "godot-tools notice",
    title_pos = opts.title_pos or "center",
    footer = opts.footer or "q/esc to close",
    footer_pos = "center",
  })

  vim.wo[win].wrap = true
  local close = function()
    vim.api.nvim_win_close(win, true)
  end
  vim.keymap.set("n", "q", close, { buffer = buf, nowait = true })
  vim.keymap.set("n", "<esc>", close, { buffer = buf, nowait = true })

  if opts.close_on_focus_loss then
    vim.api.nvim_create_autocmd("WinLeave", {
      buffer = buf,
      once = true,
      callback = function()
        vim.schedule(function()
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
        end)
      end,
    })
  end
end)

return M
