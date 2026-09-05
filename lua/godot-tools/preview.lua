local log = require "godot-tools.log"

local M = {}

---@param path string file to preview
---@param opts previewopts?
function M.scene_file(path, opts)
  local scene = require("godot-tools.resource").load_scene(path)
  if not scene then
    log.error "unable to parse scene!"
    return
  end

  local render = require "godot-tools.render"
  local lines, hls = render.scene_tree(scene)

  vim.cmd.vsplit()
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, lines)
  for _, hl in ipairs(hls) do
    vim.api.nvim_buf_set_extmark(preview_buf, render.ns_id, hl.line, hl.col_beg, {
      end_col = hl.col_end,
      hl_group = hl.group,
    })
  end
  local preview_title = vim.fs.relpath(vim.fn.getcwd(), path) or path
  vim.api.nvim_buf_set_name(preview_buf, "Preview of " .. preview_title)
  vim.api.nvim_win_set_buf(0, preview_buf)

  vim.bo[preview_buf].modifiable = false
  vim.bo[preview_buf].buftype = "nofile"
  vim.bo[preview_buf].swapfile = false

  vim.wo[0].number = false
  vim.wo[0].relativenumber = false
  vim.wo[0].signcolumn = "yes"

  local kopts = { buffer = preview_buf, silent = true, nowait = true }
  vim.keymap.set("n", "q", "<cmd>close<CR>", kopts)
end

---@param bufnr? buffer to preview, defaults to current
---@param opts {}?
function M.scene_buffer(bufnr, opts)
  bufnr = bufnr or 0
  if not vim.api.nvim_buf_is_valid(bufnr) then
    log.error("invalid buffer: %d", bufnr)
    return
  end

  local buf_name = vim.api.nvim_buf_get_name(bufnr)
  if vim.fs.ext(buf_name) ~= "tscn" then
    log.error("cannot preview non-tscn buffer: %s", buf_name)
    return
  end

  local path = vim.fs.normalize(vim.fs.abspath(buf_name))
  M.scene_file(path, opts)
end

return M
