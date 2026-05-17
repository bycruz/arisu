local ffi = require("ffi")
local Image = require("arisu-image")
local stbtt = require("stbtt-sys")

local ATLAS_WIDTH = 512
local ATLAS_HEIGHT = 512

---@class Bitmap
---@field image Image
---@field charData stbtt.ffi.BakedChar
---@field pixelSize number
---@field firstChar integer
---@field numChars integer
---@field characters string
---@field atlasWidth integer
---@field atlasHeight integer
---@field ascent number Distance from baseline to top of font (in pixels)
---@field descent number Distance from baseline to bottom of font (negative, in pixels)
---@field lineGap number Extra spacing between lines (in pixels)
local Bitmap = {}
Bitmap.__index = Bitmap

---@alias BitmapQuad { u0: number, v0: number, u1: number, v1: number, width: number, height: number, xOffset: number, yOffset: number, xAdvance: number, baseline: number }

---@param char string
---@return BitmapQuad
function Bitmap:getCharUVs(char)
	local charIdx = assert(
		self.characters:find(char, 1, true),
		"Character '" .. char .. "' not found in bitmap characters."
	) - 1

	local xpos = ffi.new("float[1]", 0.0)
	local ypos = ffi.new("float[1]", 0.0)
	local quad = stbtt.AlignedQuad()

	stbtt.getBakedQuad(
		self.charData,
		self.atlasWidth,
		self.atlasHeight,
		charIdx,
		xpos,
		ypos,
		quad,
		1 -- opengl_fillrule (1 = OpenGL-style, 0 = D3D-style)
	)

	-- In stbtt's coordinate system, the baseline is at y=0.
	-- quad.y0 is the offset from baseline to the top of the glyph (negative).
	-- baseline is the distance from the top of the glyph's bounding box down to the baseline.
	local baseline = -quad.y0

	return {
		u0 = quad.s0,
		v0 = quad.t0,
		u1 = quad.s1,
		v1 = quad.t1,
		width = quad.x1 - quad.x0,
		height = quad.y1 - quad.y0,
		xOffset = quad.x0,
		yOffset = quad.y0,
		xAdvance = xpos[0],
		baseline = baseline
	}
end

---@param string string
---@return BitmapQuad[]
function Bitmap:getStringUVs(string)
	local quads = {}
	for i = 1, #string do
		local char = string:sub(i, i)
		local quad = self:getCharUVs(char)
		table.insert(quads, quad)
	end

	return quads
end

---@param fontData string Raw TTF/OTF font file bytes
---@param pixelSize number Font size in pixels for the atlas
---@param characters string String containing all characters to bake into the atlas
---@return Bitmap?
---@return string?
function Bitmap.fromTTF(fontData, pixelSize, characters)
	local numChars = #characters
	local firstChar = characters:byte(1)

	-- Allocate grayscale atlas buffer (1 byte per pixel from stbtt)
	local atlasPixels = ffi.new("uint8_t[?]", ATLAS_WIDTH * ATLAS_HEIGHT, 0)

	-- Allocate baked character data array
	local charData = stbtt.BakedChar(numChars)

	-- Copy font data into an FFI byte buffer
	local ffiFontData = ffi.new("uint8_t[?]", #fontData, fontData)

	-- Bake the font atlas
	local result = stbtt.bakeFontBitmap(
		ffiFontData,
		0, -- offset into font data
		pixelSize,
		atlasPixels,
		ATLAS_WIDTH,
		ATLAS_HEIGHT,
		firstChar,
		numChars,
		charData
	)

	if result == 0 then
		return nil, "stbtt_BakeFontBitmap failed — atlas too small for the given font size and characters"
	end

	-- Get scaled font metrics (ascent, descent, lineGap)
	local ascent = ffi.new("float[1]")
	local descent = ffi.new("float[1]")
	local lineGap = ffi.new("float[1]")
	stbtt.getScaledFontVMetrics(
		ffiFontData,
		0, -- font index
		pixelSize,
		ascent,
		descent,
		lineGap
	)

	-- Convert grayscale to RGBA (white text + alpha from coverage)
	local rgbaPixels = ffi.new("uint8_t[?]", ATLAS_WIDTH * ATLAS_HEIGHT * 4)
	for i = 0, ATLAS_WIDTH * ATLAS_HEIGHT - 1 do
		local coverage = atlasPixels[i]
		local ri = i * 4
		rgbaPixels[ri + 0] = 255 -- R
		rgbaPixels[ri + 1] = 255 -- G
		rgbaPixels[ri + 2] = 255 -- B
		rgbaPixels[ri + 3] = coverage -- A
	end

	local image = Image.new(ATLAS_WIDTH, ATLAS_HEIGHT, 4, rgbaPixels, "")

	return setmetatable({
		image = image,
		charData = charData,
		pixelSize = pixelSize,
		firstChar = firstChar,
		numChars = numChars,
		characters = characters,
		atlasWidth = ATLAS_WIDTH,
		atlasHeight = ATLAS_HEIGHT,
		ascent = ascent[0],
		descent = descent[0],
		lineGap = lineGap[0]
	}, Bitmap)
end

---@param characters string
---@param pixelSize number
---@return Bitmap
---@return string?
function Bitmap.fromSystemFont(characters, pixelSize)
	return nil, "System font loading not yet implemented — use Bitmap.fromTTF instead"
end

return Bitmap
