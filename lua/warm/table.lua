-- More than mostly needed table functions

local spr = require("warm.spr")
local main = {}

-- A accurate way to check is empty or empty items
--
-- Since #table only returns the total indexable items in the table
--
-- use this to check for keys of any type.
---@param tbl table<any>
---@return boolean
function main.is_empty(tbl)
  spr.validate({ "table" }, { tbl })
  return next(tbl) == nil
end

---Return the table type
--
---Not a table `-1`, empty `0`, list `1`, dict `2`, mixed `3`,
---@param tbl table
---@return -1|0|1|2|3
function main.type(tbl)
  if type(tbl) ~= "table" then return -1 end
  local kc = #main.get_keys(tbl)
  -- stylua: ignore
  return spr.switch(true)({
    { main.is_empty(tbl), 0 },     -- Empty
    { (#tbl == kc), 1 },           -- List
    { (#tbl == 0 and kc > 0), 2 }, -- Dict
    { (#tbl ~= kc), 3 },           -- Mixed
  })
end

---Get all keys in a table
---@param tbl table<any, any>
---@return table<any>
function main.get_keys(tbl)
  spr.validate({ "table" }, { tbl })
  if main.is_empty(tbl) then return {} end
  local keys = {}
  for key, _ in pairs(tbl) do
    table.insert(keys, key)
  end
  return keys
end

---Get all values in a table
---@param tbl table<any, any>
---@return table<any>
function main.get_vals(tbl)
  spr.validate({ "table" }, { tbl })
  if main.is_empty(tbl) then return {} end
  local vals = {}
  for _, val in pairs(tbl) do
    table.insert(vals, val)
  end
  return vals
end

---Does nothing
function main.replicate(tbl, imp) end

---Make table flat, not containing tables
---the contents of nested tables will be in first level
---@param tbl table
---@return table<any>
function main.flatten(tbl)
  local res = {}
  for k, v in pairs(tbl) do
    local tp = type(v)
    if tp == "table" then
      res = main.extend(res, main.flatten(v))
    else
      res[k] = v
    end
  end
  return res
end

---Extend to a table checking for duplicate keys
--
--- If `force` is true, it will not keep duplicate keys values
---@param ts table
---@param td table
---@param force? boolean
---@return table
function main.extend(ts, td, force)
  spr.validate({ "table", "table", { "nil", "boolean" } }, { ts, td, force })
  if main.is_empty(ts) then return td end
  if main.is_empty(td) then return ts end
  local res = ts
  for k, v in pairs(td) do
    if res[k] == nil or (type(res[k]) == "table" and #main.get_keys(res[k]) == 0) then
      res[k] = v
    elseif force then
      res[k] = v
    else
      res[#res + 1] = v
    end
  end
  return res
end

---Merges the given tables into one table
---@param ts table
---@param td table
---@return table
function main.merge(ts, td)
  spr.validate({ "table", "table" }, { ts, td })
  if main.is_empty(ts) then return td end
  if main.is_empty(td) then return ts end
  local res = ts
  for k, _ in pairs(td) do
    if td[k] ~= nil then res[k] = td[k] end
  end
  return res
end

---Merge the given tables recursively
---@param ts table
---@param td table
---@return table
function main.deep_merge(ts, td)
  spr.validate({ "table", "table" }, { ts, td })
  if main.is_empty(td) then return ts end
  if main.is_empty(ts) then return td end
  local res = ts
  for k, v in pairs(td) do
    if td[k] ~= nil then
      local t1, t2 = type(res[k]), type(v)
      if t1 == "table" and t2 == "table" then
        res[k] = main.deep_merge(res[k], td[k])
      elseif t1 == "table" then
        res[k] = table.insert(res[k], v)
      elseif t2 == "table" then
        res[k] = table.insert(v, res[k])
      else
        res[k] = v
      end
    end
  end
  return res
end

---Filter a table by a given condition function
---@param tbl table
---@param condition fun(k, v):boolean
---@param recurse? boolean
---@return table
function main.filter(tbl, condition, recurse)
  tbl, condition, recurse = table.unpack(
    spr.parse_args(
      { "table", "function", { "nil", "boolean", def = false } },
      { tbl, condition, recurse }
    )
  )
  local result = {}
  for k, v in pairs(tbl) do
    if type(v) == "table" and recurse then
      result[k] = main.filter(v, condition, true)
    elseif condition(k, v) then
      -- If table has indexed values, then treat the
      -- table as a list and not a k, v pairs table.
      -- if #tbl >= 1 then
      if type(k) == "number" then
        table.insert(result, v)
      else
        result[k] = v
      end
    end
  end
  return result
end

---Check whether an item exists in a table
---@param tbl table
---@param val any
---@return boolean
function main.contains(tbl, val)
  spr.validate({ "table", "some" }, { tbl, val })
  for _, v in pairs(tbl) do
    if v == val then return true end
  end
  return false
end

---Returns true if all items are some (not nil) or true, otherwise false.
---@param tbl table
---@return boolean
function main.all(tbl)
  spr.validate({ "table" }, { tbl })
  for _, v in pairs(tbl) do
    if v == nil or v == false then return false end
  end
  return true
end

---Returns true if any item is some (not nil) or true, otherwise false.
---@param tbl table
---@return boolean
function main.any(tbl)
  spr.validate({ "table" }, { tbl })
  for _, v in pairs(tbl) do
    if v ~= nil and v then return true end
  end
  return false
end

---Turn all table values into a boolean value
---@param tbl table
---@param recurse? boolean
---@return table<boolean>
function main.boolean(tbl, recurse)
  tbl, recurse = table.unpack(
    spr.parse_args({ "table", { "boolean", "nil", def = false } }, { tbl, recurse })
  )
  local recursive = (recurse ~= nil and recurse ~= false) or false
  local result = {}
  for k, v in pairs(tbl) do
    local vt = type(v)
    if vt == "table" and recursive then
      result[k] = main.boolean(v, true)
    else
      result[k] = (
        v ~= nil
        and (
          (vt ~= "string" and vt ~= "table")
          or (vt == "string" and #v > 0)
          or (vt == "table" and not main.is_empty(v))
        )
      )
    end
  end
  return result
end

---Run fun for every k, v from the given table
---
---fun receives k, v from the given table, this function (map)
---and the function fun (self)
-- ```lua
-- local prcstbl = main.map(table, function(k, v, map, me)
--   -- Make recursive mapping
--   if type(v) == "table" then return map(v, me) end
--   -- Do stuff with k, v
-- end)
-- ```
---@param tbl table Table to map
---@param fun fun(k, v, map:function, me:function) Callback to run for each item
---@param track boolean Keep track of key names
---@return table<integer, {key:string|integer, ret:any}>
function main.map(tbl, fun, track)
  if track == nil then track = false end
  spr.validate({ "table", "function", "boolean" }, { tbl, fun, track })
  local rvl = {}
  for k, v in pairs(tbl) do
    rvl[#rvl + 1] = fun(k, v, main.map, fun)
    if track then rvl[#rvl] = {
      key = k,
      ret = rvl[#rvl],
    } end
  end
  return rvl
end

-- Returns a function that returns every element of the given indexed table.
--
-- When all items are mapped, restarts the process
---@param tbl table
---@return fun():any|nil
function main.iter(tbl)
  spr.validate({ "table" }, { tbl })
  -- A table with one item only... is not worth it
  if #main.get_keys(tbl) < 2 then error("cannot return values from tiny tables") end
  local ks = nil
  return function()
    local k, v = next(tbl, ks)
    if k == nil then
      k, v = next(tbl, ks)
    end
    ks = k
    return v
  end
end

---Shuffle items in a table
---@generic T
---@param tbl T[]
---@return T[]
function main.shuffle(tbl)
  spr.validate({ "table" }, { tbl })
  local size = #tbl
  for i = size, 1, -1 do
    local rand = math.random(size)
    tbl[i], tbl[rand] = tbl[rand], tbl[i]
  end
  return tbl
end

---Remove duplicate values
---@param tbl table
---@return table
function main:dedup(tbl)
  local seen = {}
  local res = {}
  for k, v in pairs(tbl) do
    if not seen[v] then
      res[k] = v
      seen[v] = true
    end
  end
  return res
end

---Return the dominant value based on the given function
---@param tbl table
---@param fun fun(k, cur)
---@param mem? any
---@return any
function main.reduce(tbl, fun, mem)
  local res = mem
  for _, v in pairs(tbl) do
    res = fun(v, res)
  end
  return res
end

---Return tbl[idx] or a random item from it
---@param tbl any[]
---@param idx? integer
---@return any
function main.choose(tbl, idx)
  spr.validate({ "table", { "nil", "number" } }, { tbl, idx })
  if idx ~= nil and tbl[idx] ~= nil then return tbl[idx] end
  return tbl[math.random(#tbl)]
end

---Lua table.unpack with dict like list support, as well as key filtering.
---
---Note that keys are returned as they where defined or added, so { a = 1, b = "2" } will return 1, "2"
---
---Returns the elements from the given list. This function is equivalent to
---```lua
---    return list[i], list[i+1], ···, list[j]
---```
---By default, `i` is `1` and `j` is `#list`.
---@generic T
---@param tbl table<any, T>
---@param i?   integer
---@param j?   integer
---@param keys?   table
---@return T   ...
---@nodiscard
function main.unpack(tbl, i, j, keys)
  spr.validate(
    { "table", { "nil", "number" }, { "nil", "number" }, { "nil", "table" } },
    { tbl, i, j, keys }
  )
  -- Manage negative numbers
  if i == nil then i = 1 end
  if j == nil then j = #tbl end
  -- if i < 0 then i = 1 end -- A table can have
  -- if j < 0 then j = #tbl end -- negative numbers

  local range = spr.range(i, j)

  if keys == nil or #keys == 0 then keys = main.get_keys(tbl) end
  local res = {}
  for k, v in pairs(tbl) do
    local tk = type(k)
    if tk == "string" then
      if main.contains(keys, k) then table.insert(res, v) end
    elseif tk == "number" then
      if range % k then table.insert(res, v) end
    end
  end
  return table.unpack(res)
end

---Return the JSON string representation of a Lua table
-- Do not use
---@param tbl table
---@param indent? number
---@param ignorefn? boolean
---@return string
function main.jsonify(tbl, indent, ignorefn, __nested__)
  if __nested__ ~= "__nested__" and __nested__ ~= "__key__" then
    local args = spr.parse_args({
      "table",
      { "nil", "number", def = 1 },
      { "nil", "boolean", def = false },
    }, { tbl, indent, ignorefn })
    tbl, indent, ignorefn = table.unpack(args, 1, #args)
  else -- a nested execution
    local type_of_val = type(tbl)
    if type_of_val == "string" then
      return '"' .. tbl .. '"'
    elseif type_of_val == "function" then
      local retstr = '"fun(...):any"'
      if ignorefn then retstr = '""' end
      if __nested__ == "__key__" then
        retstr = '"' .. tostring(tbl):match("[^%s]+$") .. ':fun():any"'
      end
      return retstr
    elseif type_of_val == "table" then
      if __nested__ == "__key__" then
        return '"' .. tostring(tbl):match("[^%s]+$") .. ':table"'
      end
    else
      return tostring(tbl)
    end
  end
  ---@cast indent number
  -- Here tbl should always be a table
  local next_key, _ = next(tbl)
  local start, ends = "{", "}"
  if type(next_key) == "number" then
    start, ends = "[", "]"
  end
  local json_str = start .. "\n"
  local comma = false
  for key, value in pairs(tbl) do
    if comma then
      json_str = json_str .. ",\n"
    else
      comma = true
    end
    local val_str = main.jsonify(value, indent + 1, ignorefn, "__nested__")
    if type(key) == "number" then
      json_str = json_str .. string.rep("  ", indent) .. val_str
    else
      local key_str = main.jsonify(key, indent, ignorefn, "__key__")
      json_str = json_str .. string.rep("  ", indent) .. key_str .. ": " .. val_str
    end
  end
  json_str = json_str .. "\n" .. string.rep("  ", indent - 1) .. ends
  return json_str
end

---Get a formatted string representation of the table
---@param tbl table
---@param opts? {indent:number, ignore:string[]|integer[], ignore_func:boolean, recurse:integer|nil}
---@return string
function main.stringify(tbl, opts)
  local dopts = {
    indent = 1,
    ignore_func = true,
    ignore = {},
    recurse = nil,
  }
  if type(tbl) ~= "table" then return tostring(tbl) end
  tbl, opts =
    table.unpack(spr.parse_args({ "table", { "nil", "table", def = dopts } }, { tbl, opts }))
  if main.is_empty(tbl) then return "{}" end
  -- Set up options
  if not opts.__nested__ then
    opts.indent, opts.ignore_func, opts.ignore, opts.recurse = table.unpack(spr.parse_args({
      { "nil", "number", def = 1 },
      { "nil", "boolean", def = true },
      { "nil", "table", def = {} },
      { "nil", "number" },
    }, { opts.indent, opts.ignore_func, opts.ignore, opts.recurse }))
  end
  opts.spacing = string.rep("  ", opts.indent)
  local function tbl_has(l, s)
    for _, v in pairs(l) do
      if v == s then return true end
    end
    return false
  end

  local func_buffer = ""
  local function ret_buf_add(key, value, _indentnt, idx)
    if _indentnt == nil then func_buffer = func_buffer .. opts.spacing end
    if key == nil then
      func_buffer = func_buffer .. tostring(value)
    elseif type(key) == "number" then
      if idx == key then
        func_buffer = func_buffer .. tostring(value)
        return true
      else
        func_buffer = func_buffer .. "[" .. tostring(key) .. "] = " .. tostring(value)
      end
    else
      local keywords = {
        "and",
        "break",
        "do",
        "else",
        "end",
        "false",
        "for",
        "function",
        "if",
        "in",
        "local",
        "nil",
        "not",
        "or",
        "repeat",
        "return",
        "then",
        "true",
        "until",
        "while",
      }
      if string.match(key, "[-+/%*%%{}%[%]^#~!@$~`&()]") or tbl_has(keywords, key) then
        func_buffer = func_buffer .. '["' .. tostring(key) .. '"] = ' .. tostring(value)
      else
        func_buffer = func_buffer .. tostring(key) .. " = " .. tostring(value)
      end
    end
    return false
  end

  if opts.__nested__ ~= true then func_buffer = "{\n" end
  local index = 1
  for k, v in pairs(tbl) do
    if tbl_has(opts.ignore, k) then goto continue end
    if type(v) == "table" then
      if opts.recurse ~= nil and opts.recurse < 1 or main.is_empty(v) then
        if ret_buf_add(k, "{},\n", nil, index) then index = index + 1 end
        goto continue
      end
      if ret_buf_add(k, "{\n", nil, index) then index = index + 1 end
      local rec_for_recursion = nil
      if opts.recurse ~= nil then rec_for_recursion = opts.recurse - 1 end
      ret_buf_add(
        nil,
        main.stringify(v, {
          recurse = rec_for_recursion,
          ignore = opts.ignore,
          ignoreFns = opts.ignore_func,
          indent = opts.indent + 1,
          colored = opts.colored,
          __nested__ = true,
        }),
        true,
        index
      )
      ret_buf_add(nil, "},\n")
    elseif type(v) == "function" then
      if opts.ignore_func then goto continue end
      if ret_buf_add(k, "function() end,\n", nil, index) then index = index + 1 end
    elseif type(v) == "string" then
      if ret_buf_add(k, '"' .. tostring(v) .. '",\n', nil, index) then index = index + 1 end
    else
      if ret_buf_add(k, tostring(v) .. ",\n", nil, index) then index = index + 1 end
    end
    ::continue::
  end
  if #opts.spacing == 2 then func_buffer = func_buffer .. "}" end
  return func_buffer
end

-- Copy some functions
main.sort = table.sort

-- function main.pack(...) return { n = select("#", ...), ... } end
-- main.pack = table.pack

---Returns a new table with all arguments stored into keys `1`, `2`, etc.
--
---***Without*** the n field (use table.pack or just #table)
---@generic T
---@param ...T
---@return table
function main.pack(...) return { ... } end
main.remove = table.remove
main.insert = table.insert

return main
