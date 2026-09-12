---@class gdtools.Project.Parser
---@field src string source content
---@field pos integer current parser pos
---@field parsed_root boolean true if we have already parsed the root section
local Parser = {}
Parser.__index = Parser

local function str2class(s)
  local cl = {}
  for c in s:gmatch "." do
    cl[c] = true
  end
  return cl
end

Parser.whitespace = str2class " \t\r\n"
Parser.comment_start = str2class "#;"
Parser.number = str2class "0123456789.-abcdefABCDEFx"
Parser.pat_ident_start = '^[%w_"]$'
Parser.pat_ident_cont = "^[%w_%.%/]$"
Parser.pat_num_start = "^[%-%d]$"

---@param src string source to parse
---@return gdtools.Project.Parser
function Parser.new(src)
  local parser = setmetatable({}, Parser)
  parser.src = src
  parser.pos = 1
  parser.parsed_root = false
  return parser
end

---@param source string config file source
---@return gdtools.GodotConfig
function Parser.parse(source)
  local log = require "godot-tools.log"
  local parser = Parser.new(source)
  local conf = {}
  for section in parser:section_stream() do
    conf[section.tag] = section.values
  end
  return conf
end

function Parser:sections()
  local sections = {}
  local n = 1
  for section in self:section_strem() do
    sections[n] = block
    n = n + 1
  end
  return sections
end

function Parser:section_stream()
  return function()
    return self:next()
  end
end

---@return gdtools.Project.Parser.Section
function Parser:next()
  self:skip_whitespace()

  if self:eof() then
    return nil
  end

  local cur = self:at()
  local start = self.pos
  local tag
  if cur:match(Parser.pat_ident_start) then
    if self.parsed_root then
      error(("Unexpected values outside of block at %d"):format(self.pos))
    end
    tag = "root"
    self.parsed_root = true
  else
    self:expect "["
    tag = self:take_until_char "]"
    self:advance()
  end
  local values = self:take_section_values()
  local stop = self.pos
  return { tag = tag, values = values, start = start, stop = stop }
end

---@return string # current char
function Parser:at()
  return self.src:sub(self.pos, self.pos)
end

---@param len integer peek distance
---@return string # the char `len` bytes ahead
function Parser:peek(len)
  len = len or 1
  return self.src:sub(self.pos + len, self.pos + len)
end

function Parser:advance()
  self.pos = self.pos + 1
end

---@param expected string expected char
function Parser:expect(expected)
  if self:at() ~= expected then
    error(("expected '%s', got '%s' at pos %d"):format(expected, self:at(), self.pos))
  end
  self:advance()
end

---@param to_skip table<string, boolean> chars to skip
function Parser:skip_while_any(to_skip)
  while not self:eof() and to_skip[self:at()] do
    self:advance()
  end
end

---@param to_take table<string, boolean> chars to take
---@return string
function Parser:take_while_any(to_take)
  local start = self.pos
  while not self:eof() and to_take[self:at()] do
    self:advance()
  end
  return self.src:sub(start, self.pos - 1)
end

---@param char string
---@return boolean true if `char` was found and consumed
function Parser:take_if_char(char)
  if self:at() == char then
    self:advance()
    return true
  end
  return false
end

---@param char string char to stop at
---@return string span does not include `char`
function Parser:take_until_char(char)
  return self:take_until_any({ [char] = true })
end

---@return string span does include `sent_char`
function Parser:take_until_any(sent_chars)
  local start = self.pos
  while not self:eof() and not sent_chars[self:at()] do
    self:advance()
  end
  if self:eof() then
    error "Unexpected eof"
  end
  return self.src:sub(start, self.pos - 1)
end

--- skips whitespace AND comments
function Parser:skip_whitespace()
  while Parser.whitespace[self:at()] or Parser.comment_start[self:at()] do
    self:skip_while_any(Parser.whitespace)
    if Parser.comment_start[self:at()] then
      self:skip_line()
    end
  end
end

function Parser:skip_line()
  while self:at() ~= "\n" do
    self:advance()
  end
  self:advance()
end

function Parser:take_section_values()
  self:skip_whitespace()
  local values = {}
  while not self:eof() and self:at():match(Parser.pat_ident_start) do
    self:skip_whitespace()
    local cur = self:at()
    if not cur:match(Parser.pat_ident_start) then
      break
    end

    local key = self:take_ident()
    self:skip_while_any(Parser.whitespace)
    self:expect "="
    self:skip_while_any(Parser.whitespace)
    local value = self:take_variant()
    self:skip_whitespace()
    values[key] = value
  end
  return values
end

---@return gdtools.Variant? # if `nil`, Parser is not pointing at a valid variant
function Parser:take_variant()
  local cur = self:at()
  local start = self.pos

  -- strings
  if (cur == "&" and self:peek() == '"') or cur == '"' then
    local is_stringname = false
    if cur == "&" then
      is_stringname = true
      self:advance()
    end
    self:advance()
    start = self.pos
    cur = self:at()
    while cur ~= '"' do
      if cur == "\\" then
        if self:peek() == '"' then
          self:advance()
        end
      end
      self:advance()
      cur = self:at()
      if self:eof() then
        error "Unterminated string"
      end
    end
    local str_value = self.src:sub(start, self.pos - 1)
    self:advance()
    return is_stringname and { _tag = "stringname", str = str_value } or str_value

  -- numbers
  elseif cur:match(Parser.pat_num_start) then
    local raw = self:take_while_any(Parser.number)
    local num = tonumber(raw) or error(("invalid num in take_variant: %d"):format(start))
    return num

  -- arrays
  elseif cur == "[" then
    self:advance()
    local arr = {}
    local n = 0
    while not self:eof() and self:at() ~= "]" do
      self:skip_while_any(Parser.whitespace)
      local var = self:take_variant(Parser.value_num)
      arr[n + 1] = var
      self:skip_while_any(Parser.whitespace)
      local comma = self:take_if_char ","
      if comma and type(var) == "nil" then
        error(("invalid array at pos: %d"):format(start))
      elseif not comma and self:at() ~= "]" then
        error(("Expected ',' in array pos: %d"):format(self.pos))
      end
      n = n + 1
    end
    if self:eof() then
      error "Unterminated array"
    end
    self:expect "]"
    return { _tag = "array", data = arr }

  -- dictionaries
  elseif cur == "{" then
    self:advance()
    local entries = {}
    local n = 0
    while not self:eof() and self:at() ~= "}" do
      self:skip_while_any(Parser.whitespace)
      local key = self:take_variant(Parser.value_num)
      if not key then
        error(("expected dict key at pos %d got nil variant"):format(start))
      end
      self:skip_while_any(Parser.whitespace)
      self:expect ":"
      self:skip_while_any(Parser.whitespace)
      local value = self:take_variant(Parser.value_num)
      if not key then
        error(("expected dict value at pos %d got nil variant"):format(start))
      end
      entries[n + 1] = { key, value }
      self:skip_while_any(Parser.whitespace)
      local comma = self:take_if_char ","
      self:skip_while_any(Parser.whitespace)
      n = n + 1
    end
    if self:eof() then
      error "Unterminated dict"
    end
    self:expect "}"
    return { _tag = "dict", data = entries }

  -- constructors and builtin constants
  elseif cur:match(Parser.pat_ident_start) then
    local cons = self:take_ident()
    if cons == "true" or cons == "false" then
      return cons == "true"
    elseif cons == "null" then
      return { _tag = "null" }
    elseif cons == "Object" then
      return self:take_object()
    end
    self:skip_while_any(Parser.whitespace)
    local _type = nil
    if self:take_if_char "[" then
      _type = self:take_until_char "]"
      self:advance()
    end
    self:skip_while_any(Parser.whitespace)
    self:expect "("
    local args = {}
    local n = 0
    while not self:eof() and self:at() ~= ")" do
      self:skip_while_any(Parser.whitespace)
      local var = self:take_variant(Parser.value_num)
      args[n + 1] = var
      self:skip_while_any(Parser.whitespace)
      local comma = self:take_if_char ","
      if comma then
        if type(var) == "nil" then
          error(("invalid call at pos: %d"):format(start))
        end
      else
        self:skip_while_any(Parser.whitespace)
        if self:at() ~= ")" then
          error(("invalid call at pos: %d"):format(start))
        end
      end
      n = n + 1
    end
    if self:eof() then
      error "Unterminated call expr"
    end
    self:expect ")"
    return { _tag = "call", cons = cons, type = _type, args = args }

  -- invalid variants
  else
    return nil
  end
end

---@return gdtools.Variant
function Parser:take_object()
  local start = self.pos
  self:skip_whitespace()
  self:expect "("
  local class = self:take_ident()
  self:skip_whitespace()
  self:expect ","
  self:skip_whitespace()
  local data = {}
  local n = 0
  local comma = true
  while not self:eof() and self:at() ~= ")" do
    local field = self:take_variant()
    if type(field) ~= "string" then
      error(("expected object field type to be a string at pos: %d"):format(start))
    end
    if not comma then
      error(("expected ',' to separate object fields at pos: %d"):format(start))
    end
    self:skip_whitespace()
    self:expect ":"
    self:skip_whitespace()
    local value = self:take_variant()
    if type(value) == "nil" then
      error(("expected valid variant in object at pos: %d"):format(start))
    end
    data[n + 1] = { field, value }
    self:skip_whitespace()
    comma = self:take_if_char ","
    self:skip_whitespace()
    n = n + 1
  end

  if self:eof() then
    error "Unterminated Object"
  end

  self:expect ")"

  return { _tag = "object", class = class, data = data }
end

---@return string
function Parser:take_ident()
  local start = self.pos
  if self:at() == '"' then
    local var = self:take_variant()
    if type(var) ~= "string" then
      local var_type = type(var)
      var_type = var_type == "table" and var._tag or var_type
      error(("expected ident at %d, got var: %s"):format(start, var_type))
    end
    return var
  end
  while not self:eof() and self:at():match(Parser.pat_ident_cont) do
    self:advance()
  end
  if self:eof() then
    error "Unexpected eof"
  end
  return self.src:sub(start, self.pos - 1)
end

function Parser:eof()
  return self.pos > #self.src
end

---@class gdtools.Project.Parser.Section
---@field tag string block type
---@field values table<string, gdtools.Variant>
---@field start integer start pos
---@field stop integer end pos, includes trailng whitespace

return Parser
