local M = {}

---@param filepath string path of file to search
---@param pattern string pattern to search for, must capture
---@return string? match first match of `pattern` inside the file at `filepath`
function M.extract_from_file(filepath, pattern)
  local f = io.open(filepath, "r")
  if not f then
    return nil
  end
  for line in f:lines() do
    local target = line:match(pattern)
    if target then
      f:close()
      return target
    end
  end
  f:close()
  return nil
end

--- creates a file extractor that given filepath
--- returns the first match of `pattern` within the file or nil.
---@param pattern string pattern to match on
---@return fun(filepath: string): string?
function M.extractor(pattern)
  return function(filepath) return M.extract_from_file(filepath, pattern) end
end

return M
