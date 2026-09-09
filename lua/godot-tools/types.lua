---@meta
error "requiring a meta file is a bug"

---@class gdtools.Command
---@field fn fun(ctx: gdtools.Command.Context) function to run
---@field nargs integer number of required arguments
---@field complete (fun(args: string[], bang: boolean): string[]?|string[])? command line completion function or list

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

---@class gdtools.Resource.Ref
---@field uid? string # godot uid
---@field path? string # godot res path

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
---@field nodes gdtools.Node[]

---@class gdtools.Node
---@field name string
---@field type string?
---@field parent string?
---@field unique_id integer
---@field instance {call_expr: string}?
---@field values gdtools.Resource.Value[]

---@alias gdtools.Resource.Value table<string, gdtools.Variant>

---@alias gdtools.Variant
---| number
---| string
---| boolean
---| { _tag: "call", cons: string, args: gdtools.Variant[] }
---| { _tag: "stringname", str: string }
---| { _tag: "array", data: gdtools.Variant[] }
---| { _tag: "dict", data: { gdtools.Variant, gdtools.Variant } }
---| { _tag: "null" }
