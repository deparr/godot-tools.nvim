local regex = require "godot-tools.blink.regex"

local M = {}

M.rejected_extensions = { "import", "uid" }

---@param context blink.cmp.Context
function M.dirname(context)
  local line_before_cursor = context.line:sub(1, context.bounds.start_col - (context.bounds.length == 0 and 1 or 0))
  -- hack: because I'm too lazy to properly add this to the vim regex
  if not line_before_cursor:match "res://" then
    return nil
  end
  local s = regex.PATH:match_str(line_before_cursor)
  if not s then
    return nil
  end
  local dirname = string.gsub(string.sub(line_before_cursor, s + 2), regex.NAME .. "*$", "")
  return vim.fn.resolve(vim.fs.joinpath(vim.fn.getcwd(), dirname))
end

function M.entry_to_completion_item(entry, dirname, range, opts)
  local is_dir = entry.type == "directory"
  local CompletionItemKind = require("blink.cmp.types").CompletionItemKind
  local insert_text = is_dir and entry.name .. "/" or entry.name
  return {
    label = insert_text,
    kind = is_dir and CompletionItemKind.Folder or CompletionItemKind.File,
    insertText = insert_text,
    textEdit = { newText = insert_text, range = range },
    sortText = (is_dir and "1" or "2") .. entry.name:lower(), -- Sort directories before files
    data = { path = entry.name, full_path = dirname .. "/" .. entry.name, type = entry.type },
  }
end

function M.candidates(context, dirname, opts)
  local fs = require "blink.cmp.sources.path.fs"
  local async = require "blink.cmp.lib.async"
  local ranges = M.get_text_edit_ranges(context)
  local results = {}
  local cancelled = false

  -- Prevents excessive memory growth when scanning huge directories
  local mem_usage_kb = collectgarbage "count"
  local threshold_kb = 100 * 1024 -- 100Mb
  if mem_usage_kb > threshold_kb then
    collectgarbage "collect"
  end

  return async.task.new(function(resolve, reject)
    fs.scan_dir_async(dirname, function(entries_chunk)
      if cancelled then
        return
      end

      for _, entry in ipairs(entries_chunk) do
        if
          entry.name:sub(1, 1) ~= "."
          and not vim.list_contains(M.rejected_extensions, vim.fn.fnamemodify(entry.name, ":e"))
        then
          local kind = entry.type == "directory" and ranges.directory or ranges.file
          local item = M.entry_to_completion_item(entry, dirname, kind, opts)
          results[#results + 1] = item
          if #results >= opts.max_entries then
            vim.print(string.format("%d entries in path source reached, further files ignored.", opts.max_entries))
            cancelled = true
            return
          end
        end
      end
    end)
      :map(function()
        resolve(results)
      end)
      :catch(reject)
  end)
end

function M.get_text_edit_ranges(context)
  local line_before_cursor = context.line:sub(1, context.cursor[2])
  local next_letter_is_slash = context.line:sub(context.cursor[2] + 1, context.cursor[2] + 1) == "/"

  local last_part_idx = M.get_last_path_part(line_before_cursor)

  -- TODO: return the insert and replace ranges, instead of only the insert range
  return {
    file = {
      start = { line = context.cursor[1] - 1, character = last_part_idx - 1 },
      ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] },
    },
    directory = {
      start = { line = context.cursor[1] - 1, character = last_part_idx - 1 },
      -- replace the slash after the cursor, if it exists
      ["end"] = { line = context.cursor[1] - 1, character = context.cursor[2] + (next_letter_is_slash and 1 or 0) },
    },
  }
end

function M.get_last_path_part(path)
  local i = #path
  local start_pos = 1
  while i > 0 do
    local char = path:sub(i, i)

    -- Forward slash (linux/mac delimiter)
    if char == "/" then
      start_pos = i + 1
      break

    -- Backslash (windows delimiter or escape sequence)
    elseif char == "\\" then
      if i ~= #path then
        -- if the next character is a special character, it's likely
        -- an escape sequence
        local next_char = path:sub(i + 1, i + 1)
        if not next_char:match "[ \"'`$&*(){}[]|;:<>?]" then
          start_pos = i + 1
          break
        end
      else
        start_pos = i + 1
        break
      end
    end

    i = i - 1
  end

  return start_pos
end

return M
