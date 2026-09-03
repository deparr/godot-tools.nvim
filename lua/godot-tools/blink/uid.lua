--- @module 'blink.cmp'
--- @type blink.cmp.Source
local godot_uid = {}

local ft_cmp_kind = setmetatable({
  gd = vim.lsp.protocol.CompletionItemKind.Class,
  cs = vim.lsp.protocol.CompletionItemKind.Class,
  tres = vim.lsp.protocol.CompletionItemKind.Constant,
  tscn = vim.lsp.protocol.CompletionItemKind.Constructor,
  gdshader = vim.lsp.protocol.CompletionItemKind.Color,
  glsl = vim.lsp.protocol.CompletionItemKind.Color,
}, {
  __index = function(_, _)
    return vim.lsp.protocol.CompletionItemKind.File
  end,
})

local cache = {
  uids = nil,
  time = 0,
}

function godot_uid.invalidate_cache()
  cache.uids = nil
  cache.time = 0
end

local cache_invalidate_threshold = 60 * 5

local enabled_fts = { "cs", "gdscript", "gdresource" }

function godot_uid.new(opts, _)
  local self = setmetatable({}, { __index = godot_uid })
  self.opts = vim.tbl_deep_extend("keep", opts, {})
  return self
end

function godot_uid:enabled()
  return (vim.list_contains(enabled_fts, vim.bo.ft)) and require("util").in_gdproj
end

function godot_uid:get_trigger_characters()
  return { "/" }
end

function godot_uid:get_completions(context, callback)
  callback = vim.schedule_wrap(callback)

  local line_before_cursor = context.line:sub(1, context.bounds.start_col - (context.bounds.length == 0 and 1 or 0))
  if not line_before_cursor:match "uid://" then
    return callback { is_incomplete_forward = false, is_incomplete_backward = false, items = {} }
  end

  if os.time() - cache.time >= cache_invalidate_threshold then
    godot_uid.invalidate_cache()
  end

  if cache.uids then
    return callback { is_incomplete_forward = false, is_incomplete_backward = false, items = cache.uids }
  end

  -- vim.notify("shelling out for uids")
  vim.system({ "fd", "-e", "uid" }, { text = true }, function(result)
    if result.code ~= 0 then
      callback()
      return
    end

    local paths = vim.split(result.stdout, "\n")
    local items = vim
      .iter(paths)
      :map(function(path)
        local f = io.open(path, "r")
        local uid = nil
        if f then
          uid = f:read "*l"
          f:close()
        end
        return uid
            and {
              name = vim.fn.fnamemodify(path, ":t:r"),
              path = path,
              uid = uid,
            }
          or nil
      end)
      :filter(function(item)
        return item ~= nil
      end)
      :map(function(item)
        local kind = ft_cmp_kind[vim.fn.fnamemodify(item.name, ":e")]
        return {
          label = item.name,
          kind = kind,
          insertText = item.uid,
          path = item.path,
        }
      end)
      :totable()

    cache.uids = items
    cache.time = os.time()
    callback { is_incomplete_forward = false, is_incomplete_backward = false, items = items }
  end)
end

function godot_uid:resolve(item, callback)
  item.documentation = {
    kind = "plaintext",
    value = item.path,
  }
  callback(item)
end

function godot_uid:execute(context, item, callback, default_implementation)
  default_implementation()
  callback()
end

return godot_uid
