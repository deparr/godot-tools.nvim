---@class gdtools.Command
---@field fn fun(ctx: gdtools.Command.Context) function to run
---@field nargs integer number of required arguments
---@field complete (fun(args: string[]): string[])? command line completion function

---@class gdtools.Command.Context
---@field cmd string
---@field args string[]
---@field bang boolean

---@class gdtools.Resource
---@field type string
---@field format integer
---@field uid string
---@field values gdtools.Resource.Value[]
---@field sub_resources gdtools.SubResource

---@class gdtools.SubResource
---@field type string
---@field id string
---@field values gdtools.Resource.Value[]

---@class gdtools.ExtResource
---@field type string
---@field uid string
---@field path string
---@field id string

---@class gdtools.Scene
---@field uid string
---@field format integer
---@field ext_resources gdtools.ExtResource[]
---@field sub_resources gdtools.SubResource[]
---@field nodes gdtools.Node

---@class gdtools.Node
---@field name string
---@field type string?
---@field parent string?
---@field unique_id integer
---@field instance {call_expr: string}?
---@field values gdtools.Resource.Value[]

---@alias gdtools.Resource.Value table<string, gdtools.Variant>
---@alias gdtools.Variant number|string|boolean|{call_expr: string}|{string_name: string}
