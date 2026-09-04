---@class gdtools.Resource.Parser
---@field src string source contents
---@field pos integer current parser pos
local Parser = {}
Parser.__index = Parser

local function str2class(s)
  local cl = {}
  for c in s:gmatch(".") do cl[c] = true end
  return cl
end

Parser.whitespace = str2class(" \t\r\n")
Parser.attr_num = str2class("0123456789.-e")
Parser.value_num = str2class("0123456789.-abcdefABCDEFx")
Parser.key_value_sep = str2class(" =")

Parser.pat_ident_cont = "^[%w_]$"
Parser.pat_ident_start = "^[_%a]$"
Parser.pat_attr_num_start = "^[%-%d]$"

---@param src string source to parse
---@return gdtools.Resource.Parser
function Parser.new(src)
  local parser = setmetatable({}, Parser)
  parser.src = src
  if parser.src:sub(-1, -1) != "\n" then
    parser.src = parser.src .. "\n"
  end
  parser.pos = 1
  return parser
end

---@return gdtools.Resource.Parser.Block[]
function Parser:parse()
  if self.pos != 1 then
    error("parse() called on parser not at start")
  end
  local blocks = {}
  local n = 1
  for block in self:block_stream() do
    blocks[n] = block
    n = n + 1
  end
  return blocks
end

---@return fun(): gdtools.Resource.Parser.Block? # iterator over the remaining blocks
function Parser:block_stream()
  return function()
    return self:next()
  end
end


---@return string # char currently pointed at
function Parser:at()
  return self.src:sub(self.pos, self.pos)
end

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
  if self:at() != expected then
    error(("expected '%s', got '%s' at pos %d"):format(expected, self:at(), self.pos))
  end
  self:advance()
end

---@return gdtools.Resource.Parser.Block # next block or nil if at eof
function Parser:next()
  self:skip_while_any(Parser.whitespace)

  if self:eof() then
    return nil
  end

  while self:at() == ";" do
    self:skip_line()
    self:skip_while_any(Parser.whitespace)
  end

  self:expect("[")

  local start = self.pos
  local tag = self:take_until_any({[" "] = true, ["]"] = true})
  local attrs = self:take_block_attrs()
  local values = self:take_block_values()
  local stop = self.pos
  return { tag = tag, attrs = attrs, start = start, values = values, stop = stop }
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

function Parser:skip_line()
  while self:at() != "\n" do
    self:advance()
  end
  self:advance()
end

---@param char string char to stop at
---@return string span does not include `char`
function Parser:take_until_char(char)
  return self:take_until_any({[char] = true})
end


---@return string span does include `sent_char`
function Parser:take_until_any(sent_chars)
  local start = self.pos
  while not self:eof() and not sent_chars[self:at()] do
    self:advance()
  end
  if self:eof() then
    error("Unexpected eof")
  end
  return self.src:sub(start, self.pos - 1)
end

---@param char string char to stop at
---@return string span includes `char`
function Parser:take_to_char(char)
  return self:take_to_any({[char] = true})
end


---@return string span, includes `sent_char`
function Parser:take_to_any(sent_chars)
  local start = self.pos
  while not self:eof() and not sent_chars[self:at()] do
    self:advance()
  end
  if self:eof() then
    error("unexpected eof")
  end
  local span = self.src:sub(start, self.pos)
  self:advance()
  return span
end

---@return gdtools.Resource.Parser.Block.Attrs[]
function Parser:take_block_attrs()
  local attrs = {}
  while not self:eof() do
    self:skip_while_any(Parser.whitespace)
    local cur = self:at()
    if cur:match(Parser.pat_ident_start) then
      local key = self:take_until_any(Parser.key_value_sep)
      self:skip_while_any(Parser.whitespace)
      self:expect("=")
      self:skip_while_any(Parser.whitespace)
      local value = self:take_variant(Parser.attr_num)
      attrs[key] = value
    elseif cur == "=" then
      error(("node attr missing key at pos: %d"):format(self.pos))
    elseif cur == "]" then
      break
    elseif cur == "[" then
      error("TODO Nested block header!")
    end
  end

  if self:eof() then
    error("unexpected eof")
  end

  self:advance()
  return attrs
end

--todo better 'call_expr'
--todo handle string names &""
---@return gdtools.Variant
function Parser:take_variant(allowed_num_chars)
  local cur = self:at()

  if cur == '"' then
    self:advance()
    local start = self.pos
    cur = self:at()
    while cur != '"' do
      if cur == "\\" then
        if self:peek() == '"' then
          self:advance()
        end
      end
      self:advance()
      cur = self:at()
      if self:eof() then
        error("Unexpected eof")
      end
    end
    local str_value = self.src:sub(start, self.pos - 1)
    self:advance()
    return str_value

  elseif cur:match(Parser.pat_attr_num_start) then
    local raw = self:take_while_any(allowed_num_chars)
    local num = tonumber(raw) or error(("invalid num in take_variant: %d"):format(self.pos))
    return num

  elseif cur:match(Parser.pat_ident_start) then
    local checkpoint = self.pos
    if cur == "t" or cur == "f" then
      local raw_bool = self:take_until_any(Parser.whitespace)
      if raw_bool == "true" or raw_bool == "false" then
        return raw_bool == "true"
      end
    end
    self.pos = checkpoint
    local call_expr = self:take_to_char(")")
    return { call_expr = call_expr }
  else
    error(("Unexpected '%s' at pos %d"):format(cur, self.pos))
  end
end

---@return gdtools.Resource.Parser.Block.Values
function Parser:take_block_values()
  self:skip_while_any(Parser.whitespace)
  local values = {}
  while not self:eof() and self:at() != "[" do
    local cur = self:at()
    if not cur:match(Parser.pat_ident_start) then
      error(("Unexpected '%s' at pos %d"):format(cur, self.pos))
    end

    local key = self:take_until_any(Parser.key_value_sep)
    self:skip_while_any(Parser.whitespace)
    self:expect("=")
    self:skip_while_any(Parser.whitespace)
    local value = self:take_variant(Parser.value_num)
    values[key] = value

    self:skip_while_any(Parser.whitespace)
  end
  return values
end

function Parser:eof()
  return self.pos > #self.src
end

---@class gdtools.Resource.Parser.Block
---@field tag string block type
---@field attrs gdtools.Resource.Parser.Block.Attrs
---@field values gdtools.Resource.Parser.Block.Values
---@field start integer start pos
---@field stop integer end pos, includes trailng whitespace

---@alias gdtools.Resource.Parser.Block.Attrs table<string, gdtools.Variant>
---@alias gdtools.Resource.Parser.Block.Values table<string, gdtools.Variant>

return Parser
