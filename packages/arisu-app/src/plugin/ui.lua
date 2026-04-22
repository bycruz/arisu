---@class arisu.plugin.UI
---@field layoutPlugin arisu.plugin.Layout
---@field renderPlugin arisu.plugin.Render
local UI = {}
UI.__index = UI

---@param layoutPlugin arisu.plugin.Layout
---@param renderPlugin arisu.plugin.Render
function UI.new(layoutPlugin, renderPlugin)
	return setmetatable({ layoutPlugin = layoutPlugin, renderPlugin = renderPlugin }, UI)
end

local function toNDC(pos, screenSize)
	return (pos / (screenSize * 0.5)) - 1.0
end

--- Converts a z-index to an NDC z-value
---@param z number?
local function convertZ(z)
	return 1 - math.min(z or 0, 100000) / 1000000
end

---@param z number
---@param windowWidth number
---@param windowHeight number
---@param vertices number[]
---@param indices number[]
local function addBorderQuad(bx, by, bw, bh, color, z, windowWidth, windowHeight, vertices, indices)
	if bw <= 0 or bh <= 0 then
		return
	end

	local baseIdx = #vertices / 10
	local left = toNDC(bx, windowWidth)
	local right = toNDC(bx + bw, windowWidth)
	local top = -toNDC(by, windowHeight)
	local bottom = -toNDC(by + bh, windowHeight)

	-- stylua: ignore
	for _, v in ipairs({
		left, top, convertZ(z + 1), color.r, color.g, color.b, color.a, 0, 0, 0,
		right, top, convertZ(z + 1), color.r, color.g, color.b, color.a, 0, 0, 0,
		right, bottom, convertZ(z + 1), color.r, color.g, color.b, color.a, 0, 0, 0,
		left, bottom, convertZ(z + 1), color.r, color.g, color.b, color.a, 0, 0, 0,
	}) do
		table.insert(vertices, v)
	end

	-- stylua: ignore
	for _, idx in ipairs({
		baseIdx, baseIdx + 1, baseIdx + 2,
		baseIdx, baseIdx + 2, baseIdx + 3,
	}) do
		table.insert(indices, idx)
	end
end

---@param layout arisu.ComputedLayout
local function generateLayoutQuads(layout, parentX, parentY, vertices, indices, windowWidth, windowHeight, parentZ)
	local x = (parentX or 0) + (layout.x or 0)
	local y = (parentY or 0) + (layout.y or 0)
	local width = layout.width
	local height = layout.height
	local z = math.max(layout.zIndex or 0, parentZ or 0)

	local color = layout.style.bg or { r = 1.0, g = 1.0, b = 1.0, a = 1.0 }
	local baseIdx = #vertices / 10

	local left = toNDC(x, windowWidth)
	local right = toNDC(x + width, windowWidth)
	local top = -toNDC(y, windowHeight)
	local bottom = -toNDC(y + height, windowHeight)

	local textureId = 0 -- default white texture
	if layout.style.bgImage then
		textureId = layout.style.bgImage
	end

	local u0, v0, u1, v1 = 0, 0, 1, 1
	if layout.style.bgImageUV then
		u0 = layout.style.bgImageUV.u0 or 0
		v0 = layout.style.bgImageUV.v0 or 0
		u1 = layout.style.bgImageUV.u1 or 1
		v1 = layout.style.bgImageUV.v1 or 1
	end

	-- stylua: ignore
	for _, v in ipairs({
		left, top, convertZ(z), color.r, color.g, color.b, color.a, u0, v0, textureId,
		right, top, convertZ(z), color.r, color.g, color.b, color.a, u1, v0, textureId,
		right, bottom, convertZ(z), color.r, color.g, color.b, color.a, u1, v1, textureId,
		left, bottom, convertZ(z), color.r, color.g, color.b, color.a, u0, v1, textureId,
	}) do
		table.insert(vertices, v)
	end

	-- stylua: ignore
	for _, idx in ipairs({
		baseIdx, baseIdx + 1, baseIdx + 2,
		baseIdx, baseIdx + 2, baseIdx + 3,
	}) do
		table.insert(indices, idx)
	end

	-- Generate border quads after background (so they render on top)
	if layout.border then
		local borderTop = layout.border.top
		local borderBottom = layout.border.bottom
		local borderLeft = layout.border.left
		local borderRight = layout.border.right

		-- Top border
		if borderTop and borderTop.width and borderTop.width > 0 and borderTop.style ~= "none" then
			addBorderQuad(x, y, width, borderTop.width, borderTop.color, z, windowWidth, windowHeight, vertices, indices)
		end

		-- Bottom border
		if borderBottom and borderBottom.width and borderBottom.width > 0 and borderBottom.style ~= "none" then
			addBorderQuad(x, y + height - borderBottom.width, width, borderBottom.width, borderBottom.color, z,
				windowWidth, windowHeight,
				vertices, indices)
		end

		-- Left border
		if borderLeft and borderLeft.width and borderLeft.width > 0 and borderLeft.style ~= "none" then
			addBorderQuad(x, y, borderLeft.width, height, borderLeft.color, z, windowWidth, windowHeight, vertices,
				indices)
		end

		-- Right border
		if borderRight and borderRight.width and borderRight.width > 0 and borderRight.style ~= "none" then
			addBorderQuad(x + width - borderRight.width, y, borderRight.width, height, borderRight.color, z, windowWidth,
				windowHeight, vertices, indices)
		end
	end

	if layout.children then
		for _, child in ipairs(layout.children) do
			generateLayoutQuads(child, x, y, vertices, indices, windowWidth, windowHeight, z)
		end
	end
end

function UI:requestRedraw(window)
	window.shouldRedraw = true -- shh. I'll figure out a way to make this use the eventhandler later.
end

---@param window winit.Window
function UI:refreshView(window)
	local computedLayout = self.layoutPlugin:refreshView(window)

	local vertices, indices = {}, {}
	generateLayoutQuads(computedLayout, 0, 0, vertices, indices, window.width, window.height)

	self.renderPlugin:setRenderData(window, vertices, indices)
	self:requestRedraw(window)
end

return UI
