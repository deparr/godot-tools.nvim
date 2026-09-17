if vim.g.gd_tools_loaded then
  return
end
vim.g.gd_tools_loaded = true

vim.api.nvim_create_user_command("Godot", function(ctx)
  require("godot-tools.cli").run(ctx)
end, {
  nargs = "+",
  bang = true,
  complete = function(lead, line)
    return require("godot-tools.cli").complete(lead, line)
  end,
  desc = "godot-tools.nvim command interface",
})

do
  local function post_startup()
    local project = require "godot-tools.project"
    local config = require "godot-tools.config"
    ---@diagnostic disable-next-line unecessary-if
    if project.root and config.editor.auto_connect then
      require("godot-tools.editor").connect()
    end

    if project.root and config.project.auto_watch then
      require("godot-tools.project").start_watch()
    end
  end

  if not vim.v.vim_did_enter then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = post_startup,
      once = true,
      desc = "godot-tools.nvim post startup",
    })
  else
    post_startup()
  end
end
