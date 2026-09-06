# godot-tools.nvim

> [!IMPORTANT]
> These used to live in my personal config, but I decided they'd be easier
> to manage as a separate plugin. 
>
> As such this plugin should be considered **extremely jank and 
> unfinished**


Though if all you need is a decent Godot external editor experience you can do the following:

1. install this plugin:
```lua
-- lazy.nvim
return { "deparr/godot-tools.nvim" }

-- vim.pack
vim.pack.add({ "https://github.com/deparr/godot-tools.nvim" })
```
2. In Godot, go to `Editor Settings > Text Editor > External` and set:
    - exec_path to your nvim path
    - exec_flags to `--server 127.0.0.1:6004 --remote-send "<ESC><C-\><C-N>:Godot open {file} {line} {col}<CR>"`
    - use_external to true

3. And enjoy a moderately decent editor experience when opening scripts:
    - scripts will always open in new window, preserving what you had
      open before
    - if a script is already open, it will be focused instead of opening
      a new window
    - scripts will still open while in terminal/insert/visual mode

4. Unrelated to the plugin, but while you're in Godot settings, go ahead and disable
    `Network > Language Server > Smart Resolve`, it only makes the lsp worse



The majority of useful things are accessible through the user command:
```vim
:Godot
```

and everything is available in lua:
```lua
require("godot-tools.editor")
require("godot-tools.run")
require("godot-tools.render")
require("godot-tools.preview")
```
