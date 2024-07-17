local main = {}

-- Helper Shuffle a table
local function shuffle(tbl)
  for i = #tbl, 2, -1 do
    local j = math.random(i)
    tbl[i], tbl[j] = tbl[j], tbl[i]
  end
end

-- Get 16 random lines from current Neovim buffer if they start with spaces/tabs and are not spacing or tabs only lines
function main.get_random_lines()
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local selected_lines = {}

  -- We want 16 lines, randomize selection if more than 16
  if #lines <= 16 then shuffle(lines) end

  for _, line in ipairs(lines) do
    if (#line > 0) and (line:match("^%s+")) and (not line:match("^%s*$")) then
      table.insert(selected_lines, line)
      if #selected_lines >= 16 then break end
    end
  end

  return selected_lines
end

-- Get the indentation pattern
function main.get_indentation_pattern()
  local expandtab = vim.api.nvim_get_option_value("expandtab", {})
  if expandtab then
    return "^ +", true
  else
    return "^\t+", false
  end
end

-- Parse lines into an array of numbers, where each number is the count of leading spaces/tabs
function main.parse_leading_spaces(lines)
  local leading_counts = {}
  local pattern = main.get_indentation_pattern()

  for _, line in ipairs(lines) do
    local match = string.match(line, pattern)
    if match ~= nil then table.insert(leading_counts, match:len()) end
  end

  return leading_counts
end

-- Reduce the list
function main.reduce_list(leading_counts, base)
  table.sort(leading_counts)

  local max_width = leading_counts[#leading_counts]
  local min_width = leading_counts[1]

  -- assume the smaller amount if it is the same in list
  -- if min_width == base then return min_width end

  local res = nil
  local residue = 0
  for _ = 1, 3 do
    for _, p in ipairs(leading_counts) do
      residue = residue + p % base
      if residue ~= 0 then return res end
    end
    res = base
    base = base * 2
  end

  return res
end

-- Try to guess the right indent
function main.guess(buf, base)
  if buf == nil then buf = vim.api.nvim_get_current_buf() end
  assert(
    vim.api.nvim_buf_is_valid(buf),
    "Buffer may not be valid, re-run or give a valid buffer"
  )
  if base == nil then base = 2 end
  assert(type(base) == "number", "Base must be a number")

  local lines = main.get_random_lines()

  -- A low amount of lines is ignored
  if #lines < 2 then return nil end

  lines = main.parse_leading_spaces(lines)

  return main.reduce_list(lines, base)
end

return main
