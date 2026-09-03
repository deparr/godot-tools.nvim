local M = {}

local telescope = require "telescope"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local extract_uid = require("util").extractor 'uid="([^"]+)"'
-- local tscn_previewer = require("dpar.godot.telescope.tscn_previewer")

--- requires `fd` to be installed
---
---@param opts table telescope.pickers.new() opts
---@param uid_callback function(string) callback to execute on the selected scene's uid
function M.pick_tscn(opts, uid_callback)
  opts = opts or {}

  pickers
    .new(opts, {
      prompt_title = "Find Scene",
      finder = finders.new_oneshot_job(
        { "fd", "--type", "f", "--extension", "tscn" },
        { entry_maker = require("telescope.make_entry").gen_from_file(opts) }
      ),
      sorter = conf.file_sorter(opts),
      previewer = conf.file_previewer(opts),
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local entry = action_state.get_selected_entry()
          local uid = extract_uid(entry.path or entry.value)
          uid_callback(uid)
        end)
        return true
      end,
    })
    :find()
end

return M
