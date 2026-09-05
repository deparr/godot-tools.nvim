local M = {}

---@param opts gdtools.Render.opts?
function M.tscn_previewer(opts)
  local render = require "godot-tools.render"
  local previewers = require "telescope.previewers"
  local cache = {}

  return previewers.new_buffer_previewer({
    title = "Scene Tree",
    define_preview = function(self, entry, status)
      local path = vim.fs.normalize(entry.path, { _fast = true })
      if not cache[path] then
        local resource = require "godot-tools.resource"
        local scene = resource.load_scene(path)
        local lines, hl_spans = render.scene_tree(scene, opts)
        cache[path] = { rendered = lines, hl_spans = hl_spans }
      end

      local cached = cache[path]
      local rendered, hl_spans = cached.rendered, cached.hl_spans
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, rendered)
      for _, hl in ipairs(hl_spans) do
        vim.api.nvim_buf_set_extmark(self.state.bufnr, render.ns_id, hl.line, hl.col_beg, {
          end_col = hl.col_end,
          hl_group = hl.group,
        })
      end
    end,
  })
end

return M
