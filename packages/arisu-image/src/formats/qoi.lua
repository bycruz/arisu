local ffi = require("ffi")
local bit = require("bit")

ffi.cdef([[
    typedef struct {
        char magic[4];
        uint32_t width;
        uint32_t height;
        uint8_t channels;
        uint8_t colorspace;
    } qoi_header_t;
]])

---@class qoi.Header: ffi.cdata*
---@field magic string
---@field width number
---@field height number
---@field channels number
---@field colorspace number

local QOI = {}

-- Use tonumber instead of the actual literals since stylua complains
-- (And I don't think they distribute it with LuaJIT for CI)
local QOI_OP_RGB = tonumber("0b11111110")
local QOI_OP_RGBA = tonumber("0b11111111")

local QOI_OP_INDEX = tonumber("0b00")
local QOI_OP_DIFF = tonumber("0b01")
local QOI_OP_LUMA = tonumber("0b10")
local QOI_OP_RUN = tonumber("0b11")

local function hashPixel(r, g, b, a)
	return (r * 3 + g * 5 + b * 7 + a * 11) % 64
end

---@param value number
local function swapEndian(value)
	return bit.bor(
		bit.lshift(bit.band(value, 0xFF), 24),
		bit.lshift(bit.band(bit.rshift(value, 8), 0xFF), 16),
		bit.lshift(bit.band(bit.rshift(value, 16), 0xFF), 8),
		bit.band(bit.rshift(value, 24), 0xFF)
	)
end

---@param value number
local function bigEndian(value)
	return swapEndian(value)
end

local function hashIndex(index, r, g, b, a)
	local idx = hashPixel(r, g, b, a)
	return index[idx][0] == r and index[idx][1] == g and index[idx][2] == b and index[idx][3] == a
end

---@param width number
---@param height number
---@param channels number
---@param pixels ffi.cdata*
---@return string
function QOI.Encode(width, height, channels, pixels)
	-- Header
	local headerSize = 14
	local maxOutputSize = headerSize + width * height * (channels + 1) + 8
	local buf = ffi.new("uint8_t[?]", maxOutputSize)
	local pos = 0

	-- Write magic "qoif"
	buf[pos] = string.byte("q"); pos = pos + 1
	buf[pos] = string.byte("o"); pos = pos + 1
	buf[pos] = string.byte("i"); pos = pos + 1
	buf[pos] = string.byte("f"); pos = pos + 1

	-- Write width (big-endian)
	local beWidth = bigEndian(width)
	ffi.copy(buf + pos, ffi.new("uint32_t[1]", beWidth), 4)
	pos = pos + 4

	-- Write height (big-endian)
	local beHeight = bigEndian(height)
	ffi.copy(buf + pos, ffi.new("uint32_t[1]", beHeight), 4)
	pos = pos + 4

	-- Channels and colorspace
	buf[pos] = channels; pos = pos + 1
	buf[pos] = 0; pos = pos + 1 -- colorspace 0 = sRGB

	-- Index array: 64 entries of [r, g, b, a]
	local index = ffi.new("uint8_t[64][4]")

	-- Previous pixel
	local pr, pg, pb, pa = 0, 0, 0, 255
	local run = 0
	local pxCount = width * height
	local pxPos = 0

	for _ = 0, pxCount - 1 do
		local r = pixels[pxPos]
		local g = pixels[pxPos + 1]
		local b = pixels[pxPos + 2]
		local a = channels >= 4 and pixels[pxPos + 3] or 255

		-- Check if same as previous pixel (run-length encoding)
		if r == pr and g == pg and b == pb and a == pa then
			run = run + 1
			if run == 62 then
				-- Max run length, emit now
				buf[pos] = bit.bor(bit.lshift(QOI_OP_RUN, 6), run - 1)
				pos = pos + 1
				run = 0
			end
		else
			-- Emit any pending run
			if run > 0 then
				buf[pos] = bit.bor(bit.lshift(QOI_OP_RUN, 6), run - 1)
				pos = pos + 1
				run = 0
			end

			-- Try index
			local idx = hashPixel(r, g, b, a)
			if hashIndex(index, r, g, b, a) then
				buf[pos] = bit.bor(bit.lshift(QOI_OP_INDEX, 6), idx)
				pos = pos + 1
			else
				-- Try diff
				local dr = r - pr
				local dg = g - pg
				local db = b - pb

				if a == pa and dr >= -2 and dr <= 1 and dg >= -2 and dg <= 1 and db >= -2 and db <= 1 then
					buf[pos] = bit.bor(
						bit.lshift(QOI_OP_DIFF, 6),
						bit.lshift(bit.band(dr + 2, 0x03), 4),
						bit.lshift(bit.band(dg + 2, 0x03), 2),
						bit.band(db + 2, 0x03)
					)
					pos = pos + 1
				elseif a == pa and dg >= -32 and dg <= 31 and (dr - dg) >= -8 and (dr - dg) <= 7 and (db - dg) >= -8 and (db - dg) <= 7 then
					-- Try luma
					local vg = dg + 32
					local vrdg = (dr - dg) + 8
					local vbdr = (db - dg) + 8
					buf[pos] = bit.bor(bit.lshift(QOI_OP_LUMA, 6), vg)
					pos = pos + 1
					buf[pos] = bit.bor(bit.lshift(vrdg, 4), vbdr)
					pos = pos + 1
				else
					-- Fall back to RGB/RGBA
					if a == pa then
						buf[pos] = QOI_OP_RGB; pos = pos + 1
						buf[pos] = r; pos = pos + 1
						buf[pos] = g; pos = pos + 1
						buf[pos] = b; pos = pos + 1
					else
						buf[pos] = QOI_OP_RGBA; pos = pos + 1
						buf[pos] = r; pos = pos + 1
						buf[pos] = g; pos = pos + 1
						buf[pos] = b; pos = pos + 1
						buf[pos] = a; pos = pos + 1
					end
				end
			end

			-- Update index
			index[idx][0] = r
			index[idx][1] = g
			index[idx][2] = b
			index[idx][3] = a
		end

		pr, pg, pb, pa = r, g, b, a
		pxPos = pxPos + channels
	end

	-- Emit final run if any
	if run > 0 then
		buf[pos] = bit.bor(bit.lshift(QOI_OP_RUN, 6), run - 1)
		pos = pos + 1
	end

	-- Padding: 7 zero bytes followed by 0x01
	for _ = 1, 7 do
		buf[pos] = 0; pos = pos + 1
	end
	buf[pos] = 1; pos = pos + 1

	return ffi.string(buf, pos)
end

---@param content string
function QOI.Decode(content)
	assert(QOI.isValid(content), "Invalid QOI file")

	local header = ffi.cast("const qoi_header_t*", content) --[[@as qoi.Header]]

	local width = swapEndian(header.width)
	local height = swapEndian(header.height)
	local channels = tonumber(header.channels)
	local _colorspace = tonumber(header.colorspace)

	local finalPixelCount = width * height
	local currentPixelCount = 0
	local pos = 14

	local index = ffi.new("uint8_t[64][4]")
	for i = 0, 63 do
		index[i][0] = 0
		index[i][1] = 0
		index[i][2] = 0

		-- TODO: This alpha channel thing is probably wrong.
		-- it goes against the spec.
		-- But i'll have to get around to fixing it properly later.
		index[i][3] = channels == 4 and 0 or 255
	end

	local pixels = ffi.new("uint8_t[?]", width * height * channels)
	local pixelPos = 0

	local r, g, b, a = 0, 0, 0, 255

	while currentPixelCount < finalPixelCount do
		local op8 = string.byte(content, pos + 1)
		pos = pos + 1

		if op8 == QOI_OP_RGB then
			r = string.byte(content, pos + 1)
			g = string.byte(content, pos + 2)
			b = string.byte(content, pos + 3)
			pos = pos + 3
		elseif op8 == QOI_OP_RGBA then
			r = string.byte(content, pos + 1)
			g = string.byte(content, pos + 2)
			b = string.byte(content, pos + 3)
			a = string.byte(content, pos + 4)
			pos = pos + 4
		else
			local op2 = bit.rshift(op8, 6)
			if op2 == QOI_OP_INDEX then
				local idx = bit.band(op8, 0x3f)
				r = index[idx][0]
				g = index[idx][1]
				b = index[idx][2]
				a = index[idx][3]
			elseif op2 == QOI_OP_DIFF then
				local dr = bit.band(bit.rshift(op8, 4), 3) - 2
				local dg = bit.band(bit.rshift(op8, 2), 3) - 2
				local db = bit.band(op8, 3) - 2
				r = bit.band(r + dr, 0xff)
				g = bit.band(g + dg, 0xff)
				b = bit.band(b + db, 0xff)
			elseif op2 == QOI_OP_LUMA then
				local b2 = string.byte(content, pos + 1)
				pos = pos + 1
				local vg = bit.band(op8, 0x3f) - 32
				local vr = bit.band(bit.rshift(b2, 4), 0x0f) - 8 + vg
				local vb = bit.band(b2, 0x0f) - 8 + vg
				r = bit.band(r + vr, 0xff)
				g = bit.band(g + vg, 0xff)
				b = bit.band(b + vb, 0xff)
			elseif op2 == QOI_OP_RUN then
				local run = bit.band(op8, 0x3f)
				for i = 0, run do
					pixels[pixelPos] = r
					pixels[pixelPos + 1] = g
					pixels[pixelPos + 2] = b
					if channels == 4 then
						pixels[pixelPos + 3] = a
					end
					pixelPos = pixelPos + channels
					currentPixelCount = currentPixelCount + 1
				end
				goto continue
			end
		end

		local hashIdx = hashPixel(r, g, b, a)
		index[hashIdx][0] = r
		index[hashIdx][1] = g
		index[hashIdx][2] = b
		index[hashIdx][3] = a

		pixels[pixelPos] = r
		pixels[pixelPos + 1] = g
		pixels[pixelPos + 2] = b
		if channels == 4 then
			pixels[pixelPos + 3] = a
		end
		pixelPos = pixelPos + channels
		currentPixelCount = currentPixelCount + 1

		::continue::
	end

	return width, height, channels, pixels
end

function QOI.isValid(content)
	if #content < 14 then
		return false
	end

	local header = ffi.cast("const qoi_header_t*", content) --[[@as qoi.Header]]
	local magic = ffi.string(header.magic, 4)

	return magic == "qoif"
end

return QOI
