-- bw namespace for bitwise operations
local bw = {}

-- Right shift function
---@param a number
---@param b number
function bw.rshift(a, b)
  a = a & (2 ^ 31 - 1)
  return a >> b
end

-- Left shift function
---@param a number
---@param b number
function bw.lshift(a, b)
  a = a & (2 ^ 31 - 1)
  return a << b
end

-- OR function
---@param a number
---@param b number
function bw.bor(a, b) return a | b end

-- XOR function
---@param a number
---@param b number
function bw.bxor(a, b) return a ^ b end

-- AND function (bitwise AND)
---@param a number
---@param b number
function bw.band(a, b) return a & b end

-- Bitwise NOT function
---@param n number
function bw.bnot(n) return ~n end

-- Byte swap function
---@param n number
function bw.bswap(n)
  -- Handle negative numbers using bitwise AND with the highest positive number (2^31 - 1)
  n = n & (2 ^ 31 - 1)
  return ((n & 0xFF) << 24)
    | ((n & 0xFF00) << 8)
    | ((n & 0xFF0000) >> 8)
    | ((n & 0xFF000000) >> 24)
end

-- Rotate left function
---@param a number
---@param b number
function bw.rol(a, b)
  local carry = bw.band(a, (2 ^ 31 - 1)) >> 31 -- Extract carry bit
  return (bw.bnot(carry) & bw.lshift(a, b)) | (carry & bw.lshift(a, 1)) -- Combine shifted and carry bits
end

-- Rotate right function
---@param a number
---@param b number
function bw.ror(a, b)
  local carry = bw.band(a, 1) << 31 -- Extract carry bit
  return (bw.bnot(carry) & bw.rshift(a, b)) | (carry & bw.lshift(a, 31)) -- Combine shifted and carry bits
end

-- Convert number to binary string (tobit)
---@param n number
function bw.tobit(n)
  -- Handle negative numbers using bitwise AND with the highest positive number (2^31 - 1)
  n = n & (2 ^ 31 - 1)
  local binary = ""
  for i = 0, 31 do -- Loop through each bit position
    binary = (n & (2 ^ i)) > 0 and "1" .. binary or "0" .. binary
  end
  return binary
end

-- Convert number to hexadecimal string (tohex)
---@param n number
---@return number
function bw.tohex(n)
  -- Handle negative numbers using bitwise AND with the highest positive number (2^31 - 1)
  n = n & (2 ^ 31 - 1)
  local hex = { "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f" }
  local result = ""
  for i = 1, 4 do -- Loop through each byte (4 nibbles)
    local nibble = math.floor((n >> (4 * (i - 1))) % 16)
    result = hex[nibble + 1] .. result
  end
  return result
end

-- Get the bit lenght of a integer (Bits needed to store it)
---@param i integer
---@return integer
function bw.blen(i)
  local len = 0
  if i > 255 then
    len = 8
    i = math.floor(i / 255)
  end
  while i > 0 do
    i = math.floor(i / 2)
    len = len + 1
  end
  return len
end

return bw
