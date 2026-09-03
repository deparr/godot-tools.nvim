---@class gdtools.Command
---@field fn fun(ctx: gdtools.Command.Context) function to run
---@field nargs integer number of required arguments
---@field complete (fun(args: string[]): string[])? command line completion function

---@class gdtools.Command.Context
---@field cmd string
---@field args string[]
---@field bang boolean
