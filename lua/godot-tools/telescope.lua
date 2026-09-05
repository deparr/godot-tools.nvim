local M = {}

local telescope = require "telescope"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local gd_previewers = require "godot-tools.telescope.previewers"

---@class gdtools.Find.tscn_opts
local default_findtscn_opts = {
  ---@type boolean?
  rich_preview = false,
  ---@type table?
  preview_opts = {}
}

--- requires `fd` to be installed
---
---@param callback function(uid: string, path: string) callback action
---@param opts gdtools.Find.tscn_opts? find options
---@param ts_opts table? telscope options
function M.find_tscn(callback, opts, ts_opts)
  opts = vim.tbl_deep_extend("force", default_findtscn_opts, opts or {})
  ts_opts = ts_opts or {}

  pickers
    .new(ts_opts, {
      prompt_title = "Find Scene",
      finder = finders.new_oneshot_job(
        { "fd", "--type", "f", "--extension", "tscn" },
        { entry_maker = require("telescope.make_entry").gen_from_file(ts_opts) }
      ),
      sorter = conf.file_sorter(ts_opts),
      previewer = opts.rich_preview and gd_previewers.tscn_previewer() or conf.file_previewer(ts_opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local res = require "godot-tools.resource"
          local entry = action_state.get_selected_entry()
          -- this will always be cached on rich previews
          local uid = res.load_scene(entry.path).uid
          callback(uid, entry.path)
        end)
        return true
      end,
    })
    :find()
end

return M
