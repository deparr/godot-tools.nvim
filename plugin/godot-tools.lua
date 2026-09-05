if vim.fn.exists ":Godot" == 2 then
end

---@param cmd_line string
---@return string cmd_name, string[] args
local function parse(cmd_line)
  local split = vim.split(vim.trim(cmd_line), "%s+")
  -- for completions
  if vim.startswith(cmd_line, "Godot") then
    table.remove(split, 1)
  end
  if cmd_line:sub(-1) == " " then
    split[#split + 1] = ""
  end
  return table.remove(split, 1) or "", split
end

---@type table<string, gdtools.Command>
local commands = {
  connect = {
    fn = function(ctx)
      require("godot-tools.editor").connect(ctx)
    end,
    nargs = 0,
    complete = nil,
  },
  open = {
    fn = function(ctx)
      require("godot-tools.editor").open(ctx)
    end,
    nargs = 1,
    complete = nil,
  },
  main = {
    fn = function(ctx)
      require("godot-tools.run").main(ctx)
    end,
    nargs = 0,
    complete = nil,
  },
  scene = {
    fn = function(ctx)
      if #ctx.args < 1 and not ctx.bang then
        -- todo this should be a generic 'find' module
        require("godot-tools.telescope").find_tscn(function(uid)
          ctx.args = { uid }
          require("godot-tools.run").scene(ctx)
        end, { rich_preview = true })
        return
      end
      if ctx.bang then
        require("godot-tools.run").last(ctx)
      else
        require("godot-tools.run").scene(ctx)
      end
    end,
    nargs = 0,
    complete = nil,
  },
  preview = {
    fn = function(ctx)
      if ctx.bang then
        require("godot-tools.telescope").find_tscn(function(_, path)
          vim.cmd.edit(path)
          require("godot-tools.preview").scene_file(path)
        end)
        return
      end
      local path = ctx.args[1]
      if path then
        require("godot-tools.preview").scene_file(path)
      else
        require("godot-tools.preview").scene_buffer()
      end
    end,
    nargs = 0,
    complete = nil,
  },
}

---@param ctx gdtools.Command.Context
local function run_command(ctx)
  local log = require "godot-tools.log"
  local cmd = commands[ctx.cmd]
  if cmd == nil then
    log.error("command '%s' does not exist", ctx.cmd)
    return
  end
  if #ctx.args < cmd.nargs then
    log.error("'%s': expected at least %d args, got %d", ctx.cmd, cmd.nargs, #ctx.args)
    return
  end
  cmd.fn(ctx)
end

vim.api.nvim_create_user_command("Godot", function(ctx)
  local cmd, args = parse(ctx.args)
  local sub_ctx = {
    cmd = cmd,
    args = args,
    bang = ctx.bang,
  }
  run_command(sub_ctx)
end, {
  nargs = "+",
  bang = true,
  complete = function(_, line)
    local cmd, args = parse(line)
    if #args > 0 then
      local cmd_info = commands[cmd]
      if not cmd_info or not cmd_info.complete then
        return {}
      end
      return cmd_info.complete(args)
    end

    return vim
      .iter(vim.tbl_keys(commands))
      :filter(function(x)
        return vim.startswith(x, cmd)
      end)
      :totable()
  end,
})
