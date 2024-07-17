local uts = require("warm.uts")
-- Path utils

local main = {
  sep = package.config:sub(1, 1),
}

-- '/' as path separator is valid for windows

-- Get the base name of a file path
---@param filepath string
---@return string
function main.basename(filepath) return filepath:match("^.+" .. main.sep .. "(.+)$") or filepath end

-- Get the parent directory of a file path
---@param filepath string
---@return string
function main.parent(filepath) return filepath:match("^(.*)" .. main.sep) end

-- Split a path into a table of components
---@param path string
---@return string[]
function main.split(path)
  local components = {}
  for component in path:gmatch("[^" .. main.sep .. "]+") do
    table.insert(components, component)
  end
  return components
end

---Join paths into one, just appends
---@param parent string
---@param ... string
---@return string
function main.join(parent, ...)
  local np = parent
  for _, v in ipairs({ ... }) do
    np = string.format("%s%s%s", np, main.sep, v)
  end
  return np
end

---Use the system to know if a path points to some folder or file
-- Only Neovim
---@param path string
---@return boolean
function main.exists(path) return vim.uv.fs_stat(path) ~= nil end

return main
