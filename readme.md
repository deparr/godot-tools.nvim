# godot-tools.nvim

> [!IMPORTANT]
> These used to live in my personal config, but I decided they'd be easier
> to manage as a separate plugin. 
>
> As such this plugin should be considered **usable but somewhat jank**.
> I might make breaking changes without warning.


## editor quick start

**1.** Install the plugin:

```lua
-- lazy.nvim
-- lazy loading is not recommended, godot-tools already lazily loads its modules
return { "deparr/godot-tools.nvim", lazy = false }

-- vim.pack
vim.pack.add({ "https://github.com/deparr/godot-tools.nvim" })
```

> [!NOTE]
> You **do not** need to call `require("godot-tools").setup()` to use
> the default configuration.

**2.** Configure Godot to use Neovim

In Godot, go to `Editor Settings > Text Editor > External` and set the following:

    - exec_path -> your/path/to/nvim
    - exec_flags -> `--server 127.0.0.1:6004 --remote-send "<ESC><C-\><C-N>:Godot open {file} {line} {col}<CR>"`
    - use_external -> `true`

**3.** Back in nvim, restart or run `:Godot connect` to start listening for rpc messages.

At this point you should be able to click on scripts in Godot and have them open in Neovim.

**4.** Unrelated to the plugin, but while you're in Godot settings, go ahead and disable
    `Network > Language Server > Smart Resolve`, it only makes the lsp worse
    in my experience

## commands

The majority of useful things are accessible through the user command:
```vim
:Godot

" Run the project's main scene
:Godot main

" Run a specific scene
:Godot run

" Start listening for rpc events
:Godot connect

" Open the project in the Godot Editor
:Godot editor

" Export a preset
:Godot export

" Render a SceneTree preview
:Godot preview
```

Details on command arguments and variations are in the docs (`:h godot-tools-commands`)

## lua modules

Most godot-tools are intended to be used separately and independently

i.e. if you don't want to use a feature, it isn't loaded by default.

```lua
-- exposes the contents of project.godot to the rest of the plugin
"godot-tools.project"

-- tools for interacting with the godot editor
"godot-tools.editor"

-- wrappers for godot cli commands
"godot-tools.run"

-- tools for loading resource/scene files
"godot-tools.resource"

-- tools for rendering TUI scene trees
"godot-tools.render"

-- wrappers around godot-tools.render to open renders in splits/floats
"godot-tools.preview"

-- integrations with blink.cmp
"godot-tools.blink"
```
