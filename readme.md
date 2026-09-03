# godot-tools.nvim

These used to live in my personal config, but I decided they'd be easier
to manage as a separate plugin. 

**You will probably need nvim nightly to use these.** Also I made these for me,
you might not even want to.


The most useful tool is probably `require("godot-tools.editor").open()`
which checks to see if a script is already in an open window before opening a new one.

To use it, have nvim listen on some local port (see `connect()` in `lua/godot-tools/editor.lua` and `:h serverstart`)
and set the following godot editor settings:

```ini
text_editor/external/exec_path = "your/path/to/nvim"
text_editor/external/exec_flags = "--server 127.0.0.1:6004 --remote-send "<esc>:Godot open {file} {line} {col}<cr>""
```

### non-goals

Things I probably won't add, because I don't need/use them

- nvim-dap / other debugging support
- lsp configuration
    - literally just use:

```lua
return {
    cmd = vim.lsp.rpc.connect("127.0.0.1", 6005),
    filetypes = { "gdscript" },
    root_markers = { "project.godot" },
}
```

