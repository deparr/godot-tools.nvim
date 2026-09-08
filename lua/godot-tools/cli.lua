local M = {}

---@param cmd_line string
---@return string cmd_name, string[] args, boolean bang
local function parse(cmd_line)
  local split = vim.split(vim.trim(cmd_line), "%s+")
  local bang = false
  if vim.startswith(cmd_line, "Godot") then
    local godot = table.remove(split, 1)
    bang = godot:sub(-1) == "!"
  end
  -- for completions
  if cmd_line:sub(-1) == " " then
    split[#split + 1] = ""
  end
  return table.remove(split, 1) or "", split, bang
end

---@param lead string
---@return string[]
local function scene_complete(lead)
  ---@diagnostic disable-next-line call-non-callable
  return vim
    .iter(vim.fn.getcompletion(lead, "file"))
    :filter(function(x)
      return x:match ".%/$" or x:match "%.tscn$"
    end)
    :totable()
end

---@type table<string, gdtools.Command>
local commands = {
  connect = {
    fn = function(ctx)
      require("godot-tools.editor").connect(ctx.args[1])
    end,
    nargs = 0,
  },
  open = {
    fn = function(ctx)
      local path, line, col = ctx.args[1], ctx.args[2], ctx.args[3]
      require("godot-tools.editor").open(path, line, col)
    end,
    nargs = 1,
  },
  main = {
    fn = function(_ctx)
      require("godot-tools.run").main()
    end,
    nargs = 0,
  },
  scene = {
    fn = function(ctx)
      if #ctx.args < 1 and not ctx.bang then
        -- todo this should be a generic 'find' module
        require("godot-tools.telescope").find_tscn(require("godot-tools.run").scene, { rich_preview = true })
        return
      end
      if ctx.bang then
        require("godot-tools.run").last()
      else
        local arg = ctx.args[1] or ""
        local ref = vim.startswith(arg, "uid://") and { uid = arg }
          or { path = require("godot-tools.resource").path(arg) }
        require("godot-tools.run").scene(ref)
      end
    end,
    nargs = 0,
    complete = function(args, bang)
      return bang and nil or scene_complete(args[#args])
    end,
  },
  preview = {
    fn = function(ctx)
      local path = ctx.args[1]
      if ctx.bang then
        require("godot-tools.telescope").find_tscn(function(ref)
          local selection = ref.path or error "this is gonna be annoying to fix 😜"
          selection = selection:sub(#"res://" + 1)
          local bufnr = vim.fn.bufadd(vim.fs.normalize(selection))
          vim.api.nvim_win_set_buf(0, bufnr)
          require("godot-tools.preview").scene_file(selection)
        end, nil, { default_text = path and path or nil })
        return
      end
      if path then
        if vim.fs.ext(path) ~= "tscn" then
          require("godot-tools.log").error("can't preview non tscn file: %s", path)
          return
        end
        local bufnr = vim.fn.bufadd(vim.fs.normalize(path))
        vim.api.nvim_win_set_buf(0, bufnr)
        require("godot-tools.preview").scene_file(path)
      else
        require("godot-tools.preview").scene_buffer()
      end
    end,
    nargs = 0,
    complete = function(args, bang)
      return bang and nil or scene_complete(args[#args])
    end,
  },
}

---@param arglead string
---@param line string full cmdline
---@return string[] # completion candidates
function M.complete(arglead, line)
  local cmd, args, bang = parse(line)
  if #args > 0 then
    local cmd_info = commands[cmd]
    if not cmd_info or not cmd_info.complete then
      return {}
    end
    return type(cmd_info.complete) == "function" and cmd_info.complete(args, bang) or cmd_info.complete
  end

  ---@diagnostic disable-next-line call-non-callable
  return vim
    .iter(vim.tbl_keys(commands))
    :filter(function(x)
      return vim.startswith(x, cmd)
    end)
    :totable()
end

---@param ctx vim.api.keyset.create_user_command.command_args
function M.run(ctx)
  local cmd_name, args = parse(ctx.args)
  local log = require "godot-tools.log"
  local cmd = commands[cmd_name]
  if cmd == nil then
    log.error("command '%s' does not exist", cmd_name)
    return
  end
  if #args < cmd.nargs then
    log.error("'%s': expected at least %d args, got %d", cmd_name, cmd.nargs, #args)
    return
  end

  cmd.fn({ cmd = cmd_name, args = args, bang = ctx.bang })
end

return M
