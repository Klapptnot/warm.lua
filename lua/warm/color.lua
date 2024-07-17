local main = {}

---@alias RgbColorTbl {r:integer, g:integer, b:integer}
---@alias HslColorTbl {h:integer, s:integer, l:integer}

---@param rgb RgbColorTbl|integer[]
---@return string
function main.rgbToHex(rgb)
  local r, g, b = rgb.r or rgb[1], rgb.g or rgb[2], rgb.b or rgb[2]
  return string.format("#%02x%02x%02x", math.floor(r), math.floor(g), math.floor(b))
end

---@param hex string
---@return RgbColorTbl
function main.hexToRgb(hex)
  hex = hex:gsub("^#", "")
  return {
    r = tonumber("0x" .. hex:sub(1, 2)), --/ 255,
    g = tonumber("0x" .. hex:sub(3, 4)), --/ 255,
    b = tonumber("0x" .. hex:sub(5, 6)), --/ 255,
  }
end

---@param rgb RgbColorTbl|integer[]
---@return HslColorTbl
function main.rgbToHsl(rgb)
  local r, g, b = rgb.r or rgb[1], rgb.g or rgb[2], rgb.b or rgb[2]
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s, l = (max + min) / 2, (max + min) / 2, (max + min) / 2

  -- achromatic
  if max == min then return { h = 0, s = 0, l = l } end

  local delta = max - min
  s = l > 0.5 and delta / (2 - max - min) or delta / (max + min)
  if max == r then
    h = (g - b) / delta + (g < b and 6 or 0)
  elseif max == g then
    h = (b - r) / delta + 2
  elseif max == b then
    h = (r - g) / delta + 4
  end
  h = h / 6

  return { h = h, s = s, l = l }
end

---@param hsl HslColorTbl
---@return RgbColorTbl
function main.hslToRgb(hsl)
  -- achromatic
  if hsl.s == 0 then return { r = hsl.l, g = hsl.l, b = hsl.l } end

  local r, g, b
  local function hue2rgb(p, q, t)
    if t < 0 then t = t + 1 end
    if t > 1 then t = t - 1 end
    if t < 1 / 6 then return p + (q - p) * 6 * t end
    if t < 1 / 2 then return q end
    if t < 2 / 3 then return p + (q - p) * (2 / 3 - t) * 6 end
    return p
  end

  local q = hsl.l < 0.5 and hsl.l * (1 + hsl.s) or hsl.l + hsl.s - hsl.l * hsl.s
  local p = 2 * hsl.l - q
  return {
    r = hue2rgb(p, q, hsl.h + 1 / 3),
    g = hue2rgb(p, q, hsl.h),
    b = hue2rgb(p, q, hsl.h - 1 / 3),
  }
end

---Check if luminance is greater than {brightness} (defaults to 0.5)
---@param hex string
---@param brightness? number
---@return boolean
function main.brightness(hex, brightness)
  local rgb = main.hexToRgb(hex)
  local r, g, b = rgb.r, rgb.g, rgb.b
  -- Calculate luminance (brightness)
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  -- Define a threshold for brightness
  local threshold = brightness or 0.5
  return luminance > threshold
end

---@param hsl HslColorTbl|integer[]
---@param amount number
---@return HslColorTbl
function main.darkenHsl(hsl, amount)
  -- Clamp amount between 0 and 1
  amount = math.max(0, math.min(amount, 1))

  -- Unpack color table
  local h, s, l = hsl.h or hsl[1], hsl.s or hsl[2], hsl.l or hsl[3]

  -- Adjust lightness by the amount
  l = l - amount

  -- Clamp lightness between 0 and 1
  l = math.max(0, math.min(l, 1))

  -- Return the modified HSL table
  return { h = h, s = s, l = l }
end

---@param hsl HslColorTbl|integer[]
---@param amount number
---@return HslColorTbl
function main.brightenHsl(hsl, amount)
  -- Clamp amount between 0 and 1
  amount = math.max(0, math.min(amount, 1))

  -- Unpack color table
  local h, s, l = hsl.h or hsl[1], hsl.s or hsl[2], hsl.l or hsl[3]

  -- Adjust lightness by the amount
  l = l + amount

  -- Clamp lightness between 0 and 1
  l = math.max(0, math.min(l, 1))

  -- Return the modified HSL table
  return { h = h, s = s, l = l }
end

---@param c1 RgbColorTbl
---@param c2 RgbColorTbl
---@param qt integer
---@return string[]
function main.scale(c1, c2, qt)
  -- Check if numColors is valid
  assert(qt < 2, "Number of colors must be greater than 2")

  -- Calculate the difference between colors
  local dr = (c2.r - c1.r) / (qt - 1)
  local dg = (c2.g - c1.g) / (qt - 1)
  local db = (c2.b - c1.b) / (qt - 1)

  -- Create the color scale table
  local colors = {}
  for i = 1, qt do
    local r = math.max(math.min(c1.r + dr * (i - 1), 255), 1)
    local g = math.max(math.min(c1.g + dg * (i - 1), 255), 1)
    local b = math.max(math.min(c1.b + db * (i - 1), 255), 1)
    colors[i] = main.rgbToHex({ r, g, b })
  end

  return colors
end

return main
