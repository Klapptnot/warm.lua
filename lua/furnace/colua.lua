--
local main = {
  _VERSION = "colua 0.1.2",
  _DESCRIPTION = "Simple Lua code highlighter/colorizer for terminal output"
}

local lua_keywords = {
  ["and"] = true,
  ["break"] = true,
  ["do"] = true,
  ["else"] = true,
  ["elseif"] = true,
  ["end"] = true,
  ["false"] = true,
  ["for"] = true,
  ["function"] = true,
  ["if"] = true,
  ["in"] = true,
  ["local"] = true,
  ["nil"] = true,
  ["not"] = true,
  ["or"] = true,
  ["repeat"] = true,
  ["return"] = true,
  ["then"] = true,
  ["true"] = true,
  ["until"] = true,
  ["while"] = true,
}

-- stylua: ignore
local colors = {
  keyword   = "#845cf6",
  callable  = "#6b88f8",
  number    = "#7d2ecc",
  blockwrap = "#ffff00",
  variable  = "#910de6", -- "#9b3796",
  operator  = "#ffa0fd",
  string    = "#ffffff",
  comment   = "#646991",
}

local function hex_to_term(hex)
  hex = hex:sub(2)
  local r = tonumber(hex:sub(1, 2), 16) or 0
  local g = tonumber(hex:sub(3, 4), 16) or 0
  local b = tonumber(hex:sub(5, 6), 16) or 0
  return ("\x1b[38;2;%d;%d;%dm"):format(r, g, b)
end

---Highlight Lua code strings for terminal output
---@param code string
---@param col? table<string, string>
---@return string
function main.colua(code, col)
  local state = "default"
  local res, buf, lc = "", "", ""

  if col == nil then col = {} end
  for k, v in pairs(colors) do
    if col[k] then
      col[k] = hex_to_term(col[k])
    else
      col[k] = hex_to_term(v)
    end
  end
  col.default = "\x1b[0m"

  for i = 1, #code do
    local ch = code:sub(i, i)
    if state == "string" then
      if ch == buf:sub(1, 1) and lc ~= "\\" then
        res = res .. col.string .. buf .. ch
        buf = ""
        state = "default"
      else
        buf = buf .. ch
      end
      if ch == "\\" then ch = "" end
    elseif state == "number" then
      if ch:match("%d") then
        res = res .. ch
      else
        if string.find("%*%%%-%+%/%~%=:%.", "%" .. ch) then
          if lc ~= "-" then res = res .. col.operator .. ch end
        elseif string.find("()[]{}", "%" .. ch) then
          res = res .. col.blockwrap .. ch
        else
          buf = buf .. ch
        end
        state = "default"
      end
    elseif state == "comment" then
      res = res .. ch
      if ch == "\n" then state = "default" end
    elseif state == "default" then
      if ch:match("[%a_]") then
        buf = buf .. ch
      elseif ch == '"' or ch == "'" then
        buf = buf .. ch
        state = "string"
      else
        if lc == "-" and ch ~= "-" then res = res .. col.operator .. lc end
        if lua_keywords[buf] then
          res = res .. col.keyword .. buf
          buf = ""
        else
          if ch == "(" then
            res = res .. col.callable .. buf
          else
            res = res .. col.variable .. buf
          end
          buf = ""
        end
        if lc == ch and ch == "-" then
          res = res .. col.comment .. "--"
          state = "comment"
        elseif ch:match("%d") then
          state = "number"
          res = res .. col.number .. ch
        elseif ch:match("%[%]{}%(%)") then
          res = res .. col.blockwrap .. ch
        elseif ch:match("%s") then
          res = res .. ch
        elseif ("%*%%%-%+%/%~%=:%.,<>#"):find("%" .. ch) then
          if ch ~= "-" then res = res .. col.operator .. ch end
        elseif ("()[]{}"):find("%" .. ch) then
          if ch == "(" and buf ~= "" then
            res = res .. col.callable .. buf .. col.blockwrap .. ch
          else
            res = res .. col.blockwrap .. ch
          end
        else
          buf = buf .. col.default .. ch
        end
      end
    end

    lc = ch
  end

  if buf ~= "" then
    if state == "string" then
      res = res .. col.string .. buf .. col.default -- Unclosed string
    else
      res = res .. col.variable .. buf .. col.default
    end
  end

  return res .. col.default
end

setmetatable(main, {
  __call = function (_, code, col)
    return main.colua(code, col)
  end
})


---@diagnostic disable-next-line: cast-type-mismatch
---@cast main fun(code:string, col?:table<string, string>?):string

return main
