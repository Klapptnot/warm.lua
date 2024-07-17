---Simple expect() + opr() functions to test return values
---@param this any
---@param msg? string
---@param verbose? boolean
return function(this, msg, verbose)
  if msg == nil then msg = "... unnammed" end
  if verbose == nil then verbose = false end
  assert(type(verbose) == "boolean", "argument #3 to 'expect' must be a boolean")
  local function error_message(a, b)
    return (
      "\x1b[38;5;9m[FAILED]\x1b[0m: "
      .. msg
      .. "\n\x1b[38;5;5mExpected\x1b[0m: "
      .. tostring(b)
      .. "\n\x1b[38;5;5mGot\x1b[0m     : "
      .. tostring(a)
    )
  end
  if verbose == true then msg = msg .. " is " .. tostring(this) end
  local function proc(bad, val)
    if bad then return error_message(this, val) end
    return "\x1b[38;5;10m[PASSED]\x1b[0m: " .. msg
  end

  ---@type table<string, (fun():string)|(fun(b):string)>
  local oprs = {}
  ---`this` must be equal to `b`
  function oprs.eq(b) return proc(this ~= b, b) end

  ---`this` must not be equal to `b`
  function oprs.ne(b) return proc(this == b, b) end

  ---`this` must be less than `b`
  function oprs.lt(b) return proc(this >= b, b) end

  ---`this` must be less or equal to `b`
  function oprs.le(b) return proc(this > b, b) end

  ---`this` must be greater to `b`
  function oprs.gt(b) return proc(this <= b, b) end

  ---`this` must be greater or equal to `b`
  function oprs.ge(b) return proc(this < b, b) end

  ---`this` must be of type `b`
  ---@param b type
  function oprs.is(b) return proc(type(this) ~= b, b) end

  ---`this` must not be of type `b`
  ---@param b type
  function oprs.isnt(b) return proc(type(this) == b, b) end

  ---`this` must be ***nil***
  function oprs.is_Nil() return proc(this ~= nil, nil) end

  ---`this` must be ***true***
  function oprs.is_True() return proc(this ~= true, nil) end

  ---`this` must be ***false***
  function oprs.is_False() return proc(this ~= false, nil) end

  return oprs
end
