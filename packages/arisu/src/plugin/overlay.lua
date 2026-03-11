local ffi = require("ffi")
local hood = require("hood")

---@class plugin.Overlay.Context
---@field window winit.Window
---@field vertices number[]
---@field indices number[]
---@field nIndices number
---@field uniformBuffer hood.Buffer
---@field bindGroup hood.BindGroup
---@field overlayTexture number
---@field overlayTextureView hood.TextureView
---@field vertexBuffer hood.Buffer
---@field indexBuffer hood.Buffer

---@alias OverlayPattern "solid" | "dashed" | "marching_ants"

---@class plugin.Overlay
---@field renderPlugin arisu.plugin.Render
---@field contexts table<winit.Window, plugin.Overlay.Context>
local OverlayPlugin = {}
OverlayPlugin.__index = OverlayPlugin

local PATTERN_SOLID = 0
local PATTERN_DASHED = 1
local PATTERN_MARCHING_ANTS = 2

ffi.cdef([[
typedef struct {
    float time;
    int32_t patternType;
} OverlayUniforms;
]])

---@class OverlayUniforms: ffi.cdata*
---@field time number
---@field patternType number

local sizeofOverlayUniforms = assert(ffi.sizeof("OverlayUniforms"))

---@param renderPlugin arisu.plugin.Render
function OverlayPlugin.new(renderPlugin)
	return setmetatable({ renderPlugin = renderPlugin, contexts = {} }, OverlayPlugin)
end

---@param window winit.Window
function OverlayPlugin:register(window)
	local renderCtx = self.renderPlugin:getContext(window)
	assert(renderCtx, "Render context not found for overlay plugin")

	local device = self.renderPlugin.device
	local textureManager = self.renderPlugin.sharedResources.textureManager
	local overlayTexture = textureManager:allocate(800, 600)
	local overlayTextureView = textureManager.texture:createView({
		dimension = "2d",
		baseArrayLayer = overlayTexture,
		layerCount = 1,
	})

	local uniformBuffer = device:createBuffer({
		size = sizeofOverlayUniforms,
		usages = { "STORAGE", "COPY_DST" },
	})

	local bindGroup = device:createBindGroup({
		layout = renderCtx.overlayBindGroupLayout,
		entries = {
			{
				binding = 0,
				type = "buffer",
				buffer = uniformBuffer,
				visibility = { "FRAGMENT" },
			},
		},
	})

	local vertexBuffer = device:createBuffer({
		size = 36 * 1000,
		usages = { "VERTEX", "COPY_DST" },
	})

	local indexBuffer = device:createBuffer({
		size = ffi.sizeof("uint32_t") * 6000,
		usages = { "INDEX", "COPY_DST" },
	})

	---@type plugin.Overlay.Context
	local ctx = {
		window = window,
		vertices = {},
		indices = {},
		nIndices = 0,
		uniformBuffer = uniformBuffer,
		bindGroup = bindGroup,
		overlayTexture = overlayTexture,
		overlayTextureView = overlayTextureView,
		vertexBuffer = vertexBuffer,
		indexBuffer = indexBuffer,
	}

	self.contexts[window] = ctx
	return ctx
end

---@param window winit.Window
---@return plugin.Overlay.Context?
function OverlayPlugin:getContext(window)
	return self.contexts[window]
end

local function toNDC(pos, screenSize)
	return (pos / (screenSize * 0.5)) - 1.0
end

local function convertZ(z)
	return 1 - math.min(z or 0, 100000) / 1000000
end

---@param window winit.Window
function OverlayPlugin:clear(window)
	local ctx = self:getContext(window)
	if not ctx then
		return
	end

	ctx.vertices = {}
	ctx.indices = {}
	ctx.nIndices = 0
end

---@param window winit.Window
---@param x number
---@param y number
---@param width number
---@param height number
---@param color {r: number, g: number, b: number, a: number}
---@param thickness number?
---@param z number?
function OverlayPlugin:addBox(window, x, y, width, height, color, thickness, z)
	local ctx = self:getContext(window)
	if not ctx then
		return
	end

	thickness = thickness or 1
	z = z or 99999

	self:addLine(window, x, y, x + width, y, color, thickness, z)
	self:addLine(window, x + width, y, x + width, y + height, color, thickness, z)
	self:addLine(window, x + width, y + height, x, y + height, color, thickness, z)
	self:addLine(window, x, y + height, x, y, color, thickness, z)
end

---@param window winit.Window
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color {r: number, g: number, b: number, a: number}
---@param thickness number?
---@param z number?
function OverlayPlugin:addEllipse(window, x1, y1, x2, y2, color, thickness, z)
	local ctx = self:getContext(window)
	if not ctx then
		return
	end

	thickness = thickness or 1
	z = z or 99999

	local centerX = (x1 + x2) / 2
	local centerY = (y1 + y2) / 2
	local radiusX = math.abs(x2 - x1) / 2
	local radiusY = math.abs(y2 - y1) / 2

	local avgRadius = (radiusX + radiusY) / 2
	local segments = math.max(16, math.floor(avgRadius / 2))

	for i = 0, segments - 1 do
		local angle1 = (i / segments) * 2 * math.pi
		local angle2 = ((i + 1) / segments) * 2 * math.pi

		local px1 = centerX + math.cos(angle1) * radiusX
		local py1 = centerY + math.sin(angle1) * radiusY
		local px2 = centerX + math.cos(angle2) * radiusX
		local py2 = centerY + math.sin(angle2) * radiusY

		self:addLine(window, px1, py1, px2, py2, color, thickness, z)
	end
end

---@param window winit.Window
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param color {r: number, g: number, b: number, a: number}
---@param thickness number?
---@param z number?
function OverlayPlugin:addLine(window, x1, y1, x2, y2, color, thickness, z)
	local ctx = self:getContext(window)
	if not ctx then
		return
	end

	thickness = thickness or 1
	z = z or 99999

	local w = 800
	local h = 600

	local dx = x2 - x1
	local dy = y2 - y1
	local len = math.sqrt(dx * dx + dy * dy)

	if len < 0.001 then
		return
	end

	local nx = -dy / len
	local ny = dx / len

	local half = thickness * 0.5

	local x1a = x1 + nx * half
	local y1a = y1 + ny * half
	local x1b = x1 - nx * half
	local y1b = y1 - ny * half

	local x2a = x2 + nx * half
	local y2a = y2 + ny * half
	local x2b = x2 - nx * half
	local y2b = y2 - ny * half

	local baseIdx = #ctx.vertices / 9

	local left1 = toNDC(x1a, w)
	local top1 = toNDC(y1a, h)
	local left2 = toNDC(x1b, w)
	local top2 = toNDC(y1b, h)
	local right1 = toNDC(x2a, w)
	local bottom1 = toNDC(y2a, h)
	local right2 = toNDC(x2b, w)
	local bottom2 = toNDC(y2b, h)

	local zNDC = convertZ(z)

	for _, v in ipairs({
		left1,
		top1,
		zNDC,
		color.r,
		color.g,
		color.b,
		color.a,
		0,
		0,
		right1,
		bottom1,
		zNDC,
		color.r,
		color.g,
		color.b,
		color.a,
		len / 10,
		0,
		right2,
		bottom2,
		zNDC,
		color.r,
		color.g,
		color.b,
		color.a,
		len / 10,
		1,
		left2,
		top2,
		zNDC,
		color.r,
		color.g,
		color.b,
		color.a,
		0,
		1,
	}) do
		table.insert(ctx.vertices, v)
	end

	for _, idx in ipairs({
		baseIdx,
		baseIdx + 1,
		baseIdx + 2,
		baseIdx,
		baseIdx + 2,
		baseIdx + 3,
	}) do
		table.insert(ctx.indices, idx)
	end

	ctx.nIndices = #ctx.indices
end

---@param window winit.Window
---@param pattern OverlayPattern?
---@param time number?
function OverlayPlugin:draw(window, pattern, time)
	local ctx = self:getContext(window)
	if not ctx then
		return
	end

	local renderCtx = self.renderPlugin:getContext(window)
	if not renderCtx then
		return
	end

	pattern = pattern or "solid"
	time = time or 0

	local patternType = PATTERN_SOLID
	if pattern == "dashed" then
		patternType = PATTERN_DASHED
	elseif pattern == "marching_ants" then
		patternType = PATTERN_MARCHING_ANTS
	end

	local device = self.renderPlugin.device
	local textureManager = self.renderPlugin.sharedResources.textureManager

	local uniforms = ffi.new("OverlayUniforms") --[[@as OverlayUniforms]]
	uniforms.time = time
	uniforms.patternType = patternType
	device.queue:writeBuffer(ctx.uniformBuffer, sizeofOverlayUniforms, uniforms)

	if ctx.nIndices > 0 then
		local vertexSize = ffi.sizeof("float") * #ctx.vertices
		device.queue:writeBuffer(ctx.vertexBuffer, vertexSize, ffi.new("float[?]", #ctx.vertices, ctx.vertices))

		local indexSize = ffi.sizeof("uint32_t") * #ctx.indices
		device.queue:writeBuffer(ctx.indexBuffer, indexSize, ffi.new("uint32_t[?]", #ctx.indices, ctx.indices))

		local encoder = device:createCommandEncoder()
		encoder:beginRendering({
			colorAttachments = {
				{
					op = { type = "clear", color = { r = 0, g = 0, b = 0, a = 0 } },
					texture = ctx.overlayTextureView,
				},
			},
		})
		encoder:setPipeline(renderCtx.overlayPipeline)
		encoder:setBindGroup(0, ctx.bindGroup)
		encoder:setVertexBuffer(0, ctx.vertexBuffer)
		encoder:setIndexBuffer(ctx.indexBuffer, "u32")
		encoder:drawIndexed(ctx.nIndices, 1)
		encoder:endRendering()

		device.queue:submit(encoder:finish())
	end
end

---@param window winit.Window
---@return number?
function OverlayPlugin:getTexture(window)
	local ctx = self:getContext(window)
	return ctx and ctx.overlayTexture
end

return OverlayPlugin
