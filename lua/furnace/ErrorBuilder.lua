local uts = require("warm.uts")
local fmt = require("warm.str").format

---@class ErrorBuilder: table
local ErrorBuilder = {}

---Returns an error object, capable of showing code context in a beautiful message
---@param error? string
---@param explanation? string
---@return ErrorBuilder
function ErrorBuilder:new(error, explanation)
  -- stylua: ignore
  self.c = {
    -- Dark color
    black  = "\x1b[38;2;67;76;94m",
    red    = "\x1b[38;2;250;90;164m",
    green  = "\x1b[38;2;43;228;145m",
    yellow = "\x1b[38;2;250;148;110m",
    blue   = "\x1b[38;2;99;197;234m",
    purple = "\x1b[38;2;207;142;244m",
    cyan   = "\x1b[38;2;37;240;255m",
    white  = "\x1b[38;2;247;247;247m",
    -- Brigh color
    Black  = "\x1b[38;2;76;86;106m",
    Red    = "\x1b[38;2;250;116;178m",
    Green  = "\x1b[38;2;68;235;159m",
    Yellow = "\x1b[38;2;232;235;100m",
    Blue   = "\x1b[38;2;122;203;234m",
    Purple = "\x1b[38;2;216;166;244m",
    Cyan   = "\x1b[38;2;107;245;255m",
    White  = "\x1b[38;2;244;244;244m",
  }
  self.hg_code = true
  self.err_src = uts.fwd(true, 2)
  self.error_code = error or "UNKNOWN_ANY"
  self.explanation = explanation or "Check the data given to it"
  self.code_snip = {}
  self.lines = {}
  self.suggestions = {}
  setmetatable(self, { __index = ErrorBuilder })
  return self
end

---Add a code portion of file, where the error could be
---@param line integer Line of error (***required***)
---@param bc? integer Lines below `line` to show (default: `1`)
---@param uc? integer Lines above `line` to show (default: `2`)
---@return ErrorBuilder
function ErrorBuilder:line(line, bc, uc)
  if bc == nil then bc = 1 end
  if uc == nil then uc = 2 end
  local filepath = self.err_src

  local _, lines = uts.get_file_range(filepath, line - uc, line + bc)
  if lines ~= nil then self.code_snip = lines end
  self.code_snip.l = line
  return self
end

---`Got` X leyend above suggestions (below `Expected`)
---@param got any Mostly value types here
---@return ErrorBuilder
function ErrorBuilder:got(got)
  table.insert(self.lines, string.format("Got      : %s", got))
  return self
end

---`Expected` X leyend below file path (above `Got`)
---@param expected any Mostly what value types are expected
---@return ErrorBuilder
function ErrorBuilder:expect(expected)
  table.insert(self.lines, string.format("Expected : %s", expected))
  return self
end

---Add suggestions of code, will be syntactically highlighted
---@param suggestion string
---@return ErrorBuilder
function ErrorBuilder:suggest(suggestion)
  table.insert(self.suggestions, suggestion)
  return self
end

-- function ErrorBuilder:is(actual)
--   table.insert(self.lines, string.format("  Actual: %s", actual))
--   return self
-- end

---Whether to not use colored output
---@param code? boolean
---@return ErrorBuilder
function ErrorBuilder:monochrome(code)
  self.c = setmetatable({}, { __index = function(_, _) return "" end })
  if code ~= nil and code == false then self.hg_code = false end
  return self
end

---Build the error message string and returns it.
---Make your own process to notify it
---@return string
function ErrorBuilder:build()
  local c = self.c
  local message = fmt("{}WHAT: {}\x1b[0m\n", c.red, self.error_code)

  local hg = function(s) return s end
  if self.hg_code then hg = require("furnace.colua") end
  ---@cast hg fun(code:string, col?:table<string, string>):string
  if #self.code_snip > 0 then
    local ll = 0
    local code = ""
    for _, l in ipairs(self.code_snip) do
      if #l.c > ll then ll = #l.c end
      code = fmt("{}{2:4}|{3}\n", code, l.n, hg(l.c))
    end
    message = fmt("{1}{3}\n{2}{3}", message, code, ("-"):rep(ll + 6))
  end
  message = fmt("{}\n{}:{}\n\n", message, self.err_src, self.code_snip.l)

  for _, line in ipairs(self.lines) do
    message = fmt("{}{}\n", message, line)
  end

  message = fmt("{}{}{}\n", message, c.yellow, self.explanation)

  if #self.suggestions > 0 then
    message = message .. c.white .. "  Suggestions:\n"
    for _, suggestion in ipairs(self.suggestions) do
      message = fmt("{}    {}\n", message, hg(suggestion))
    end
  end

  return message .. c.white
end

---Throw the error. Print error and exit process
---If condition is `true` (or a truthy value) it will throw
---@param cond boolean
function ErrorBuilder:throw(cond)
  if not cond then return end
  print(self:build())
  os.exit(1)
end

return ErrorBuilder
