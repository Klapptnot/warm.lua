-- Small regex engine, when patterns are not enough

local spr = require("warm.spr")
-- stylua: ignore start

local TokenRange = {
  common     = spr.range(0, 15),
  pattern    = spr.range(16, 25),
  quantifier = spr.range(26, 35),
}

---@enum RegexTokens
-- Regex operations identifiers, modes
local RegexTokens = {
  -- End of Line
  EOL        = -1,
  -- Group options advisor ***`?`, `:`, `=`***
  PROPS      = 0,
  -- Backslash escape
  BACKSLASH  = 1,
  -- ***`^`*** and ***`$`*** symbols
  ANCHOR     = 2,
  -- Left parenthesis ***`(`***
  LPAREN     = 3,
  -- Right parenthesis ***`)`***
  LBRACE     = 4,
  -- Left square bracket ***`[`***
  LSQBRA     = 5,
  -- Left arrow quote ***`<`***
  LPLASK     = 7,
  -- Right arrow quote ***`>`***
  RPLASK     = 8,
  -- Range setter on range groups ***`-`***
  MINUS      = 9,
  -- In groups, the or operator ***`|`***
  ALTCHAIN   = 10,

  -- Anything that can be quantified or matched
  LITERAL    = 16,
  -- Right parenthesis ***`)`***
  RPAREN     = 17,
  -- Right square bracket ***`]`***
  RSQBRA     = 18,

  -- Zero or more of last token/group ***`*`***
  STAR       = 26,
  -- One or more of last token/group ***`+`***
  PLUS       = 27,
  -- Zero or one of last token/group ***`?`***
  QUESTION   = 28,
  -- n to m times the last token/group `{n, m}`
  RBRACE     = 29,
}

local RegexOperations = {
  ESCAPE     = 0,  -- Do not process next \^
  RESET      = 1,  -- Reset recording \K
  DEFREF     = 2,  -- Define a custom group
  BACKREF    = 3,  -- reference ta recored group \<>
  GRABALL    = 4,  -- *
  GRABSOME   = 5,  -- +
  LANCHOR    = 6,  -- ^
  RANCHOR    = 7,  -- $
  NEGATE     = 8,  -- ^
}
-- stylua: ignore end

local function e(r, i, m) return string.format("%s\n%s\n%" .. i .. "s", m, r, "^") end

-- Here are the muscles of each operation
---@class RegexEngine
---@field star      fun(self:RegexEngine):string? -- *
---@field plus      fun(self:RegexEngine):string? -- +
---@field maybe     fun(self:RegexEngine):string? -- ?
---@field anchor    fun(self:RegexEngine):string? -- ^ $
---@field group     fun(self:RegexEngine):string? -- ()
---@field range     fun(self:RegexEngine):string? -- []
---@field threshold fun(self:RegexEngine):string? -- {}
local RegexEngine = {}

---@alias RegexTokenStream { [1]:RegexTokens, [2]:string }

---Regex processor builder
---@param regex string
---@return RegexTokenStream
local function RegexParser(regex)
  local sb = string.byte
  TokenStream = {}
  local stack = {}
  function stack:pop(token)
    if self[#self] ~= token then return self[#self] end
    self[#self] = nil
  end
  function stack:set(token) self[#self + 1] = token end
  function stack:ask(token) return self[#self] == token end

  local i = 1
  local c = regex:sub(i, i)
  local lastToken = RegexTokens.EOL
  while c ~= "" do
    local token = spr.match(c, true)({
      ["*"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not TokenRange.pattern.match(lastToken) then
          error(e(regex, i, "Regex quantifier (*) must have a pattern to count"))
        end
        return RegexTokens.STAR
      end,
      ["+"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not TokenRange.pattern.match(lastToken) then
          error(e(regex, i, "Regex quantifier (+) must have a pattern to count"))
        end
        return RegexTokens.PLUS
      end,
      ["?"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if lastToken == RegexTokens.LPAREN then
          return RegexTokens.PROPS
        elseif not TokenRange.pattern.match(lastToken) then
          error(e(regex, i, "Regex quantifier (?) must have a pattern to count"))
        end
        return RegexTokens.QUESTION
      end,
      ["^"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if i > 1 and lastToken ~= RegexTokens.LSQBRA and lastToken ~= RegexTokens.BACKSLASH then
          error(e(regex, i, "Regex anchor (^) is not escaped"))
        end
        return RegexTokens.ANCHOR
      end,
      ["$"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if i ~= #regex and lastToken ~= RegexTokens.BACKSLASH then
          error(e(regex, i, "Regex anchor ($) is not escaped"))
        end
        return RegexTokens.ANCHOR
      end,
      ["-"] = function()
        if not stack:ask(RegexTokens.LSQBRA) then return RegexTokens.LITERAL end
        if lastToken ~= RegexTokens.BACKSLASH then
          local a, b = sb(TokenStream[#TokenStream][2]), sb(regex:sub(i + 1, i + 1))
          if b < a then
            error(e(regex, i, "Regex range is out of order, you may want to escape the `-`"))
          end
        end
        return RegexTokens.MINUS
      end,
      [":"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not stack:ask(RegexTokens.LPAREN) or lastToken ~= RegexTokens.PROPS then
          return RegexTokens.LITERAL
        end
        return RegexTokens.PROPS
      end,
      ["|"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not stack:ask(RegexTokens.LPAREN) then return RegexTokens.LITERAL end
        return RegexTokens.ALTCHAIN
      end,
      ["="] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not stack:ask(RegexTokens.LPAREN) or lastToken ~= RegexTokens.PROPS then
          return RegexTokens.LITERAL
        end
        return RegexTokens.PROPS
      end,
      ["("] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        stack:set(RegexTokens.LPAREN)
        return RegexTokens.LPAREN
      end,
      ["<"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if not stack:ask(RegexTokens.LPAREN) or lastToken ~= RegexTokens.PROPS then
          return RegexTokens.LITERAL
        end
        stack:set(RegexTokens.LPLASK)
        return RegexTokens.LPLASK
      end,
      ["["] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        stack:set(RegexTokens.LSQBRA)
        return RegexTokens.LSQBRA
      end,
      ["{"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        stack:set(RegexTokens.LBRACE)
        return RegexTokens.LBRACE
      end,
      -- Close

      [")"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.RPAREN end
        local p = stack:pop(RegexTokens.LPAREN)
        assert(p == nil, e(regex, i, "Parent () closed before child"))
        return RegexTokens.RPAREN
      end,
      [">"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        if stack:ask(RegexTokens.LPLASK) then
          local p = stack:pop(RegexTokens.LPLASK)
          return RegexTokens.RPLASK
        end
        return RegexTokens.LITERAL
      end,
      ["]"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.RSQBRA end
        local p = stack:pop(RegexTokens.LSQBRA)
        assert(p == nil, e(regex, i, "Parent [] closed before child"))
        return RegexTokens.RSQBRA
      end,
      ["}"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.RBRACE end
        local p = stack:pop(RegexTokens.LBRACE)
        assert(p == nil, e(regex, i, "Parent {} closed before child"))
        return RegexTokens.RBRACE
      end,
      ["\\"] = function()
        if lastToken == RegexTokens.BACKSLASH then return RegexTokens.LITERAL end
        return RegexTokens.BACKSLASH
      end,
      _def = function()
        if lastToken == RegexTokens.PROPS and TokenStream[#TokenStream][2] == "?" then
          error(e(regex, i, "Invalid group syntax, you may want to escape '?'"))
        end
        return RegexTokens.LITERAL
      end,
    })
    TokenStream[#TokenStream + 1] = { token, c }
    i = i + 1
    c = regex:sub(i, i)
    lastToken = token
  end
  return TokenStream
end

return RegexEngine
