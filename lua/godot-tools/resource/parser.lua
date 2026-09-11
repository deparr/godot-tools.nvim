---@class gdtools.Resource.Parser
---@field src string source contents
---@field pos integer current parser pos
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
Parser.attr_num = str2class "0123456789.-e"
Parser.value_num = str2class "0123456789.-abcdefABCDEFx"

Parser.pat_ident_cont = "^[%w_%/]$"
Parser.pat_ident_start = "^[_%a]$"
Parser.pat_attr_num_start = "^[%-%d]$"

---@param src string source to parse
---@return gdtools.Resource.Parser
function Parser.new(src)
  local parser = setmetatable({}, Parser)
  parser.src = src
  if parser.src:sub(-1, -1) ~= "\n" then
    parser.src = parser.src .. "\n"
  end
  parser.pos = 1
  return parser
end

---@enum (file) Tag known tags for resource blocks
local Tag = {
  ROOT_RESOURCE = "gd_resource",
  ROOT_SCENE = "gd_scene",
  SUB_RESOURCE = "sub_resource",
  EXT_RESOURCE = "ext_resource",
  NODE = "node",
  RESOURCE = "resource",
  CONNECTION = "connection",
}

---@param source string tscn file contents
---@return gdtools.Scene
function Parser.parse_scene(source)
  local log = require "godot-tools.log"
  local parser = Parser.new(source)
  local scene, ext_resources, sub_resources, nodes, conns = {}, {}, {}, {}, {}
  scene.ext_resources = ext_resources
  scene.sub_resources = sub_resources
  scene.nodes = nodes
  scene.conns = conns
  local found_main_tag = false
  for block in parser:block_stream() do
    if block.tag == Tag.ROOT_SCENE then
      found_main_tag = true
      scene.format = block.attrs.format
      scene.uid = block.attrs.uid
    elseif block.tag == Tag.EXT_RESOURCE then
      local ext_res = {
        type = block.attrs.type,
        uid = block.attrs.uid,
        path = block.attrs.path,
        id = block.attrs.id,
      }
      ext_resources[#ext_resources + 1] = ext_res
    elseif block.tag == Tag.SUB_RESOURCE then
      local sub_res = {
        type = block.attrs.type,
        id = block.attrs.id,
        values = block.values,
      }
      sub_resources[#sub_resources + 1] = sub_res
    elseif block.tag == Tag.NODE then
      local node = {
        name = block.attrs.name,
        type = block.attrs.type,
        parent = block.attrs.parent,
        unique_id = block.attrs.unique_id,
        instance = block.attrs.instance,
        values = block.values,
      }
      nodes[#nodes + 1] = node
    elseif block.tag == Tag.CONNECTION then
      local conn = {
        signal = block.attrs.signal,
        from = block.attrs.from,
        to = block.attrs.to,
        method = block.attrs.method,
      }
      conns[#conns + 1] = conn
    else
      log.warn(("TODO unexpected block.tag in scene: %s"):format(block.tag))
    end
  end

  if not found_main_tag then
    log.warn "Did not find main tag for scene"
  end

  return scene
end

---@param source string tres file contents
---@return gdtools.Resource
function Parser.parse_resource(source)
  local log = require "godot-tools.log"
  local parser = Parser.new(source)
  local res, sub_resources = {}, {}
  res.sub_resources = sub_resources
  local found_main_tag = false
  for block in parser:block_stream() do
    if block.tag == Tag.ROOT_RESOURCE then
      found_main_tag = true
      res.type = block.attrs.type
      res.format = block.attrs.format
      res.uid = block.attrs.uid
    elseif block.tag == Tag.SUB_RESOURCE then
      local sub_res = {
        type = block.attrs.type,
        id = block.attrs.id,
        values = block.values,
      }
      sub_resources[#res.sub_resources + 1] = sub_res
    elseif block.tag == Tag.RESOURCE then
      res.values = block.values
    else
      log.warn(("TODO unexpected block.tag in resource: %s"):format(block.tag))
    end
  end

  if not found_main_tag then
    log.warn "Did not find main tag for resource"
  end

  return res
end

--- collects the remaining blocks in `self`
---@return gdtools.Resource.Parser.Block[]
function Parser:blocks()
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

  self:expect "["

  local start = self.pos
  local tag = self:take_until_any({ [" "] = true, ["]"] = true })
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
  while self:at() ~= "\n" do
    self:advance()
  end
  self:advance()
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

---@param char string char to stop at
---@return string span includes `char`
function Parser:take_to_char(char)
  return self:take_to_any({ [char] = true })
end

---@return string span, includes `sent_char`
function Parser:take_to_any(sent_chars)
  local start = self.pos
  while not self:eof() and not sent_chars[self:at()] do
    self:advance()
  end
  if self:eof() then
    error "unexpected eof"
  end
  local span = self.src:sub(start, self.pos)
  self:advance()
  return span
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

---@return gdtools.Resource.Parser.Block.Attrs[]
function Parser:take_block_attrs()
  local attrs = {}
  while not self:eof() do
    self:skip_while_any(Parser.whitespace)
    local cur = self:at()
    if cur:match(Parser.pat_ident_start) then
      local key = self:take_ident()
      self:skip_while_any(Parser.whitespace)
      self:expect "="
      self:skip_while_any(Parser.whitespace)
      local value = self:take_variant(Parser.attr_num)
      attrs[key] = value
    elseif cur == "=" then
      error(("node attr missing key at pos: %d"):format(self.pos))
    elseif cur == "]" then
      break
    elseif cur == "[" then
      error "TODO Nested block header!"
    end
  end

  if self:eof() then
    error "Unexpected eof"
  end

  self:advance()
  return attrs
end

---@return gdtools.Variant? # if `nil`, Parser is not pointing at a valid variant
function Parser:take_variant(allowed_num_chars)
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
  elseif cur:match(Parser.pat_attr_num_start) then
    local raw = self:take_while_any(allowed_num_chars)
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
        error "Expected ',' in array"
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

---@return gdtools.Resource.Parser.Block.Values
function Parser:take_block_values()
  self:skip_while_any(Parser.whitespace)
  local values = {}
  while not self:eof() and self:at() ~= "[" do
    local cur = self:at()
    while cur == ";" do
      self:skip_line()
      self:skip_while_any(Parser.whitespace)
      cur = self:at()
    end
    if cur == "[" then
      break
    elseif not cur:match(Parser.pat_ident_start) then
      error(("Unexpected '%s' at pos %d"):format(cur, self.pos))
    end

    local key = self:take_ident()
    self:skip_while_any(Parser.whitespace)
    self:expect "="
    self:skip_while_any(Parser.whitespace)
    local value = self:take_variant(Parser.value_num)
    values[key] = value
    self:skip_while_any(Parser.whitespace)
  end
  return values
end

---@return string
function Parser:take_ident()
  local start = self.pos
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

---@class gdtools.Resource.Parser.Block
---@field tag string block type
---@field attrs table<string, gdtools.Variant>
---@field values table<string, gdtools.Variant>
---@field start integer start pos
---@field stop integer end pos, includes trailng whitespace

return Parser
