local M = {}

local telescope = require "telescope"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local gd_previewers = require "godot-tools.telescope.previewers"

--- requires `fd` to be installed
---
---@param opts table? telescope.pickers.new() opts
---@param uid_callback function(string) callback to execute on the selected scene's uid
function M.find_tscn(opts, uid_callback)
  opts = opts or {}

  pickers
    .new(opts, {
      prompt_title = "Find Scene",
      finder = finders.new_oneshot_job(
        { "fd", "--type", "f", "--extension", "tscn" },
        { entry_maker = require("telescope.make_entry").gen_from_file(opts) }
      ),
      sorter = conf.file_sorter(opts),
      previewer = gd_previewers.tscn_previewer(),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local res = require "godot-tools.resource"
          local entry = action_state.get_selected_entry()
          -- this will always be cached, unless we get really unlucky with timing
          local uid = res.load_scene(entry.path).uid
          uid_callback(uid)
        end)
        return true
      end,
    })
    :find()
end

return M
