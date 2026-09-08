local M = {}

---@param opts gdtools.Render.opts?
---@return Previewer # telescope previewr object
function M.tscn_previewer(opts)
  local render = require "godot-tools.render"
  local previewers = require "telescope.previewers"
  local cache = {}
  opts = opts or {}

  return previewers.new_buffer_previewer({
    title = "Scene Tree",
    define_preview = function(self, entry, status)
      local path = vim.fs.normalize(entry.path, { _fast = true })
      if not cache[path] then
        local resource = require "godot-tools.resource"
        local scene = resource.load_scene(path)
        local lines, hl_spans = render.scene_tree(scene, opts.render)
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

---@class gdtools.Find.tscn_opts
local default_findtscn_opts = {
  ---@type boolean?
  rich_preview = false,
  ---@type table?
  preview_opts = {},
}

--- requires `fd` to be installed
---
---@param callback function(uid: string, path: string) callback action
---@param opts gdtools.Find.tscn_opts? find options
---@param ts_opts table? telscope options
function M.find_tscn(callback, opts, ts_opts)
  opts = vim.tbl_deep_extend("force", default_findtscn_opts, opts or {})
  ts_opts = ts_opts or {}
  local conf = require("telescope.config").values
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  require("telescope.pickers")
    .new(ts_opts, {
      prompt_title = "Find Scene",
      finder = require("telescope.finders").new_oneshot_job(
        { "fd", "--type", "f", "--extension", "tscn" },
        { entry_maker = require("telescope.make_entry").gen_from_file(ts_opts) }
      ),
      sorter = conf.file_sorter(ts_opts),
      previewer = opts.rich_preview and M.tscn_previewer(opts.preview_opts) or conf.file_previewer(ts_opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local res = require "godot-tools.resource"
          local entry = action_state.get_selected_entry()
          -- rich previews ensure the scene is in cache
          local ref = opts.rich_preview and { uid = res.load_scene(entry.path).uid } or { path = res.path(entry.path) }
          callback(ref)
        end)
        return true
      end,
    })
    :find()
end

return M
