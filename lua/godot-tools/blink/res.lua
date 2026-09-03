-- todo figure out the correct types here
--- @module 'blink.cmp'
--- @type blink.cmp.Source
local godot_path = {}

local enabled_fts = { "cs", "gdscript" }

function godot_path.new(opts, _)
  local self = setmetatable({}, { __index = godot_path })
  self.opts = vim.tbl_deep_extend("keep", opts, {
    max_entries = 10000,
  })
  return self
end

function godot_path:enabled()
  return vim.list_contains(enabled_fts, vim.bo.ft)
end

function godot_path:get_trigger_characters()
  return { "/" }
end

-- based on blink's builtin path completion
-- https://github.com/saghen/blink.cmp/blob/main/lua/blink/cmp/sources/path/init.lua
function godot_path:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local lib = require "godot-tools.blink.lib"

  local dirname = lib.dirname(context)
  if not dirname then
    return callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
  end

  lib
    .candidates(context, dirname, self.opts)
    :map(function(candidates)
      callback { is_incomplete_forward = false, is_incomplete_backward = false, items = candidates }
    end)
    :catch(function()
      callback()
    end)
  return
end

function godot_path:resolve(item, callback)
  callback(item)
end

function godot_path:execute(context, item, callback, default_implementation)
  default_implementation()
  -- todo this doesnt do anything and neither does the
  -- completion.trigger.show_on_accept_on_trigger_character option
  if item.label:sub(-1) == "/" then
    vim.schedule(function()
      require("blink.cmp").show { trigger = { kind = "manual" } }
    end)
  end
  callback()
end

return godot_path
