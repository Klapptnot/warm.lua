-- UTF-8 lib for Neovim until it has it by default

local spr = require("warm.spr")
local main = {
  -- This pattern matches ***one*** UTF-8 byte sequence
  charpattern = "[\0-\x7F\xC2-\xFD][\x80-\xBF]",
}

-- Pattern for UTF-8 charsets
local charset = "[%z\0-\x7F\xC2-\xFD][\x80-\xBF]*"

---@param s string
---@return boolean
local function is_valid_utf8(s)
  local i = 1
  while i <= #s do
    local c = string.byte(s, i)

    -- Single-byte sequences (ASCII)
    if c >= 0 and c <= 127 then
      i = i + 1

      -- Two-byte sequences
    elseif c >= 194 and c <= 223 then
      local c2 = string.byte(s, i + 1)
      if not c2 or c2 < 128 or c2 > 191 then return false end
      i = i + 2

      -- Three-byte sequences
    elseif c >= 224 and c <= 239 then
      local c2 = string.byte(s, i + 1)
      local c3 = string.byte(s, i + 2)
      if
        not c2
        or not c3
        or (c == 224 and (c2 < 160 or c2 > 191))
        or (c == 237 and (c2 < 128 or c2 > 159))
        or (c2 < 128 or c2 > 191)
        or c3 < 128
        or c3 > 191
      then
        return false
      end
      i = i + 3

      -- Four-byte sequences
    elseif c >= 240 and c <= 244 then
      local c2 = string.byte(s, i + 1)
      local c3 = string.byte(s, i + 2)
      local c4 = string.byte(s, i + 3)
      if
        not c2
        or not c3
        or not c4
        or (c == 240 and (c2 < 144 or c2 > 191))
        or (c == 244 and (c2 < 128 or c2 > 143))
        or (c2 < 128 or c2 > 191)
        or c3 < 128
        or c3 > 191
        or c4 < 128
        or c4 > 191
      then
        return false
      end
      i = i + 4

      -- Otherwise, invalid
    else
      return false
    end
  end

  return true
end

---@param bytes integer[]
---@return integer
local function bytes_to_codepoint(bytes)
  local function unseq(b, seq_len)
    local code_point = b % (2 ^ (8 - seq_len))
    for i = 2, seq_len do
      local next_byte = bytes[i]
      code_point = code_point * 64 + (next_byte % 64)
    end
    -- It will never 'floor', just removes trailing fractions (.0)
    return math.floor(code_point)
  end

  local i = 1
  local code_point = 0

  while i <= #bytes do
    local byte = bytes[i]
    if byte < 128 then
      code_point = byte
      i = i + 1
    elseif byte < 224 then
      code_point = unseq(byte, 2)
      i = i + 2
    elseif byte < 240 then
      code_point = unseq(byte, 3)
      i = i + 3
    else
      code_point = unseq(byte, 4)
      i = i + 4
    end
  end

  return code_point
end

---@param c integer
---@return integer[]
local function codepoint_to_bytes(c)
  --stylua: ignore
  if c < 0x7f then -- < 128
    return {
      c -- byte 1
    }
  elseif c < 0x7ff then -- < 2048
    return {
      192 + math.floor(c / 64), -- byte 1
      128 + c % 64,             -- byte 2
    }
  elseif c <= 0xffff then -- < 65536
    return {
      224 + math.floor(c / 4096),        -- byte 1
      128 + math.floor((c % 4096) / 64), -- byte 2
      128 + c % 64,                      -- byte 3
    }
  elseif c <= 0x10ffff then                  -- < 1114111
    return {
      240 + math.floor(c / 262144),          -- byte 1
      128 + math.floor((c % 262144) / 4096), -- byte 2
      128 + math.floor((c % 4096) / 64),     -- byte 3
      128 + c % 64,                          -- byte 4
    }
  end
  error("Unicode point cannot be greater than u+10ffff")
end

---Encode characters in string to its unicode escaped representation (\uxxxx)
---@param s string
---@return string
function main.escape(s)
  local str = ""
  for _, c in main.codes(s) do
    str = string.format("%s\\u%04x", str, c)
  end
  return str
end

---Replace unicode escaped characters (\uxxxx) with the respective character
---@param s string
---@return string
function main.unescape(s)
  local s, _ = string.gsub(
    s,
    "\\u(%x%x%x%x)",
    function(esc) return main.char(tonumber(esc, 16)) end
  )
  return s
end

---Return a unknown lenght string, converting codepoints to their respective character
---@param ... integer
---@return string
---@nodiscard
function main.char(...)
  local str = ""
  for _, c in pairs({ ... }) do
    str = str .. string.char(table.unpack(codepoint_to_bytes(c)))
  end
  return str
end

---Get the length of a string containing UTF-8 characters
--
---It does this by counting non-continuous characters
---@param s string
---@return integer
function main.len(s) return select(2, s:gsub("[^\128-\193]", "")) end

---Remove characters longer than one byte
--
---If n is given, replace first n characters
---@param s string
---@param n?      integer
function main.clean(s, n)
  return s:gsub(charset, function(char)
    if #char > 1 then return "" end
    return char
  end, n)
end

---Wrapped around string.gsub to replace UTF-8 charset with repl
---@param s       string|number
---@param repl    string|number|table|function
---@param n?      integer
---@return string
---@return integer count
---@nodiscard
function main.replace(s, repl, n) return string.gsub(s, charset, repl, n) end

---Map through each character of the string
--
---fun gets each character in s and the character position number
---@generic T
---@param s string
---@param fun fun(p:integer, c:string):T
---@param init? integer
---@return table<T[]>
function main.map(s, fun, init)
  local pos = 0
  local rtb = {}
  for chr in s:gmatch(charset, init) do
    pos = pos + 1
    rtb[#rtb + 1] = table.pack(fun(pos, chr))
  end
  return rtb
end

---Iterate over all characters in strings
---@param s string
---@return fun():integer, string
function main.chars(s)
  return coroutine.wrap(function()
    main.map(s, function(p, c) return coroutine.yield(p, c) end)
  end)
end

---Returns a string that is the string `s` reversed.
---@param s string
---@return string
function main.reverse(s)
  local str = ""
  for c in s:gmatch(charset) do
    str = c .. str
  end
  return str
end

---Wrapper arround map that will return
---a iterator that returns pos, codepoint
---of each character on call
---@param s string
---@return fun(...):...unknown
function main.codes(s)
  return coroutine.wrap(function()
    local pos = 0
    main.map(s, function(_, c)
      pos = pos + #c
      return coroutine.yield(pos - (#c - 1), main.codepoint(c))
    end)
  end)
end

---Returns the position in bytes where the n character starts
---@param s string
---@param n integer
---@param i? integer
---@return integer p
function main.offset(s, n, i)
  s, n, i = table.unpack(spr.parse_args({
    "string",
    "number",
    { "nil", "number", def = 1 },
  }, { s, n, i }))
  if not is_valid_utf8(s) then error("invalid UTF-8 string") end

  -- Checks if i is a continuation byte
  if s:sub(i, #s):find(charset) ~= 1 then error("Initial position is a continuation byte") end
  if i ~= 1 then
    if n < 0 then
      s = s:sub(1, i)
    else
      s = s:sub(i)
    end
    i = 1
  end
  -- Accept n negative numbers
  if n == -1 then n = main.len(s) end
  if n < 0 then n = main.len(s) + n end
  local offset = 1
  for p, c in main.chars(s) do
    if offset >= i and p == n then
      return offset
    elseif offset > i and p == n then
      return offset + #c
    end
    offset = offset + #c
  end
  return 1
end

---Return the codepoint as integer from s character
---@param s    string
---@param i?   integer
---@param j?   integer
---@return integer code
---@return integer ...
---@nodiscard
function main.codepoint(s, i, j)
  s, i, j = table.unpack(spr.parse_args({
    "string",
    { "nil", "number", def = 1 },
    { "nil", "number", def = nil },
  }, { s, i, j }))
  if i == 0 or i > #s or (i < 0 and #s + i > #s) then
    error("bad argument #2 to 'codepoint' (out of bounds)")
  end
  -- Accept i negative number
  if i == -1 then i = #s end
  if i < 0 then i = #s + i end
  -- Accept j negative number
  if j == nil then j = i end
  if j == -1 then j = #s end
  if j < 0 then j = #s + j end
  -- Now check bytes
  if s:sub(i):find(charset) ~= 1 then error("initial position is a continuation byte") end
  local bytes = {}
  local offset = 1
  local tbi = 1
  for _, c in main.chars(s) do
    if offset > j then break end
    if offset >= i then
      bytes[tbi] = {}
      for idx = 1, #c do
        bytes[tbi][idx] = c:sub(idx, idx + 1):byte()
      end
      bytes[tbi] = bytes_to_codepoint(bytes[tbi])
      tbi = tbi + 1
    end
    offset = offset + #c
  end
  return table.unpack(bytes)
end

---Safely get a range of characters from a string with UTF-8 characters
---@param s  string
---@param i  integer
---@param j? integer
---@return string
---@nodiscard
function main.sub(s, i, j)
  local l = main.len(s)
  -- Set the right amount to cut
  local function fallback(r, l)
    if r ~= nil and type(r) == "number" and r > 0 then return r end
    return l
  end
  i = fallback(i, l)
  j = fallback(j, l)

  if i < 1 then i = 1 end
  if j > l then j = l end

  if i > j then return "" end
  local pop_char = coroutine.wrap(function() main.map(s, coroutine.yield) end)

  --stylua: ignore
  for _ = 1, i - 1 do pop_char() end
  local res = ""
  for _ = 1, j - i + 1 do
    local _, c = pop_char()
    res = res .. c
  end
  return res
end

---Wrapper around string.find, it works anyways
---@param s       string|number
---@param pattern string|number
---@param init?   integer
---@param plain?  boolean
---@return integer|nil start
---@return integer|nil end
---@return any|nil ... captured
---@nodiscard
function main.find(s, pattern, init, plain) return string.find(s, pattern, init, plain) end

return main
